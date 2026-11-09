#!/usr/bin/env python3
"""Advisory PreToolUse review for git push / gh pr create, without eval.

Review only commands whose repository and source can be resolved statically.
Unsupported commands and review results never block the requested operation.
"""
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time
import tempfile


def report(message, copilot):
    """Return review context without denying or pre-approving the operation."""
    if copilot:
        print(message)
    else:
        print(json.dumps({'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'additionalContext': message,
        }}, ensure_ascii=False))
    return 0


def skip_review(reason, copilot):
    return report(f'CodeRabbit: 自動レビューをスキップします。操作は続行します。\n{reason}', copilot)


def git(cwd, *args):
    result = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ''


@contextmanager
def review_checkout(cwd, commit):
    """Review another commit without checking out or changing the caller's worktree."""
    if git(cwd, 'rev-parse', '--verify', 'HEAD') == commit:
        yield cwd
        return
    with tempfile.TemporaryDirectory(prefix='coderabbit-review-') as directory:
        checkout = Path(directory) / 'tree'
        # Checkout hooks are unrelated to review and may deploy dotfiles on the host.
        command = ['git', '-C', str(cwd), '-c', 'core.hooksPath=/dev/null', 'worktree']
        result = subprocess.run(command + ['add', '--detach', str(checkout), commit], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or '一時 worktree を作成できませんでした。')
        try:
            yield checkout
        finally:
            removed = subprocess.run(command + ['remove', '--force', str(checkout)], capture_output=True, text=True)
            if removed.returncode:
                print('CodeRabbit: 一時 worktree の登録を削除できませんでした。git worktree list で確認してください。', file=sys.stderr)


def shell_text(text):
    """Preserve quoted literals; remove shell comments and flag active expansions."""
    out, quote, word_start, expansion, i = [], None, True, False, 0
    while i < len(text):
        c = text[i]
        if quote == "'":
            out.append(c)
            if c == "'":
                quote = None
            i += 1
            continue
        if c == "\\" and i + 1 < len(text) and (quote is None or text[i + 1] in '$`"\\\n'):
            out.extend(text[i:i + 2])
            word_start = False
            i += 2
            continue
        if quote is None and c == '#' and word_start:
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        if c == '"':
            quote = None if quote == '"' else '"'
        elif c == "'" and quote is None:
            quote = "'"
        elif c == '`' or (c == '$' and i + 1 < len(text) and text[i + 1] in '({abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@*#?$!-'):
            expansion = True
        out.append(c)
        word_start = quote is None and (c.isspace() or c in ';&|()<>')
        i += 1
    return ''.join(out), expansion


def main():
    copilot = '--copilot' in sys.argv[1:]
    try:
        event = json.load(sys.stdin)
        copilot = copilot or 'toolArgs' in event
        tool = event.get('tool_input', event.get('toolArgs', {}))
        if isinstance(tool, str):
            tool = json.loads(tool)
        command = tool.get('command', tool.get('cmd', ''))
        # Codex の shell ツールは ["bash", "-lc", "<script>"] の配列で渡すことがある。
        if (isinstance(command, list) and len(command) == 3 and all(isinstance(c, str) for c in command)
                and command[1] in ('-c', '-lc')):
            command = command[2]
        if not isinstance(command, str) or not shutil.which('coderabbit'):
            return 0
        command, expansion = shell_text(command)
        lexer = shlex.shlex(command.strip(), posix=True, punctuation_chars=';&|()<>\n')
        lexer.whitespace = ' \t\r'
        lexer.whitespace_split = True
        lexer.commenters = ''
        tokens = list(lexer)
    except (ValueError, TypeError, AttributeError):
        return 0

    # Recognize command boundaries, including semicolons and newlines. Never execute shell text.
    groups, separators, group = [], [], []
    # 2>&1 や > file は区切りではない。shlex は '2' '>&' '1' に分けるため、演算子と対象語を読み飛ばす。
    redirects = {'>', '>>', '>&', '<', '<&', '&>', '&>>', '>|'}
    skip_next = False
    for token in tokens:
        if skip_next:
            skip_next = False
            continue
        if token in redirects:
            if group and group[-1].isdigit():
                group.pop()
            skip_next = True
            continue
        if token and all(c in ';&|()<>\n' for c in token):
            if group:
                groups.append(group)
                group = []
            separators.append(token)
        else:
            group.append(token)
    if group:
        groups.append(group)

    def is_target(words):
        if words[:2] == ['git', 'push'] or words[:3] == ['gh', 'pr', 'create']:
            return True
        # Resolve literal -C below; skip review for other repository/config overrides.
        if words[:1] == ['git']:
            i = 1
            while i < len(words) and words[i].startswith('-'):
                option = words[i]
                i += 2 if option in ('-C', '-c', '--git-dir', '--work-tree') else 1
            return words[i:i + 1] == ['push']
        return False

    targets = [words for words in groups if is_target(words)]
    if not targets:
        return 0
    words = targets[0]
    cwd = Path(tool.get('workdir') or event.get('cwd') or os.getcwd())
    if not cwd.is_absolute():
        cwd = Path.cwd() / cwd
    compound = False
    # Resolve a literal leading cd; skip review if the command context is ambiguous.
    if len(groups) == 2 and len(groups[0]) == 2 and groups[0][0] == 'cd' and separators == ['&&']:
        directory = groups[0][1]
        if directory.startswith('-') or any(c in directory for c in '$`~'):
            return skip_review('CodeRabbit: cd を別の呼び出しで実行してから push / PR 作成を実行してください。', copilot)
        cwd = cwd / directory
    elif len(groups) != 1 or separators:
        # An unknown directory change cannot be assumed to target this repository.
        if any(g[:1] == ['cd'] for g in groups):
            return skip_review('CodeRabbit: cd と push / PR 作成を別の呼び出しに分けてください。', copilot)
        compound = True

    if words[:1] == ['git']:
        i = 1
        while i < len(words) and words[i].startswith('-'):
            if words[i] == '-C' and i + 1 < len(words):
                if any(c in words[i + 1] for c in '$`~'):
                    return skip_review('CodeRabbit: -C には展開を含まないパスを指定してください。', copilot)
                cwd = cwd / words[i + 1]
                i += 2
            elif words[i].startswith('-C') and len(words[i]) > 2:
                if any(c in words[i][2:] for c in '$`~'):
                    return skip_review('CodeRabbit: -C には展開を含まないパスを指定してください。', copilot)
                cwd = cwd / words[i][2:]
                i += 1
            else:
                return skip_review('CodeRabbit: git のグローバルオプションは -C のみ対応しています。', copilot)
        words = ['git'] + words[i:]

    repo = git(cwd, 'rev-parse', '--show-toplevel')
    if not repo or not (Path(repo) / '.coderabbit.yaml').is_file():
        return 0
    cwd = Path(repo)
    if compound:
        return skip_review('CodeRabbit: commit・複合コマンドと push / PR 作成を別の呼び出しに分けてください。', copilot)
    if expansion:
        return skip_review('CodeRabbit: 展開やコマンド置換を含めず、push / PR 作成を単独で実行してください。', copilot)
    head = git(cwd, 'rev-parse', '--verify', 'HEAD')
    if not head:
        return 0
    source = 'HEAD'
    if words[:2] == ['git', 'push']:
        positional = []
        flags = {'-u', '--set-upstream', '-f', '--force', '--force-with-lease', '--force-if-includes',
                 '-v', '--verbose', '-q', '--quiet', '--no-verify', '-n', '--dry-run', '--porcelain',
                 '--atomic', '--progress', '--thin', '--no-thin', '-4', '--ipv4', '-6', '--ipv6'}
        for word in words[2:]:
            if word in flags or word.startswith('--force-with-lease='):
                continue
            if word.startswith('-'):
                return skip_review('CodeRabbit: 複数 ref や未対応オプションの push は対象を確定できません。送信元を明示して push してください。', copilot)
            positional.append(word)
        if len(positional) > 2:
            return skip_review('CodeRabbit: 一度に複数 ref を push せず、送信元を1つ指定してください。', copilot)
        branch = git(cwd, 'symbolic-ref', '--quiet', '--short', 'HEAD')
        remote = (positional[0] if positional else
                  git(cwd, 'config', 'branch.' + branch + '.pushRemote') or
                  git(cwd, 'config', 'remote.pushDefault') or
                  git(cwd, 'config', 'branch.' + branch + '.remote') or 'origin')
        if (git(cwd, 'config', '--bool', 'remote.' + remote + '.mirror') == 'true' or
                git(cwd, 'config', '--bool', 'push.followTags') == 'true'):
            return skip_review('CodeRabbit: mirror / followTags の push 設定を無効にし、送信元を1つ指定してください。', copilot)
        if len(positional) == 2:
            source = positional[1].lstrip('+').split(':', 1)[0]
            if not source:
                return skip_review('CodeRabbit: 削除 push はレビュー対象を確定できません。', copilot)
        elif (git(cwd, 'config', '--get-all', 'remote.' + remote + '.push') or
                git(cwd, 'config', 'push.default') not in ('', 'simple', 'current', 'upstream', 'nothing')):
            return skip_review('CodeRabbit: push 設定から送信対象を確定できません。git push <remote> HEAD:<branch> と明示してください。', copilot)
    elif words[:3] == ['gh', 'pr', 'create']:
        args = words[3:]
        for i, word in enumerate(args):
            if word in ('--repo', '-R') or word.startswith('--repo=') or word.startswith('-R'):
                return skip_review('CodeRabbit: --repo を使わず、対象リポジトリで PR を作成してください。', copilot)
            candidate = None
            if word in ('--head', '-H'):
                candidate = args[i + 1] if i + 1 < len(args) else ''
            elif word.startswith('--head='):
                candidate = word.split('=', 1)[1]
            elif word.startswith('-H'):
                candidate = word[2:]
            if candidate is not None:
                if ':' in candidate or not candidate:
                    return skip_review('CodeRabbit: --head にはローカルで解決できるブランチを指定してください。', copilot)
                source = candidate
    else:
        return skip_review('CodeRabbit: git のグローバルオプションを外し、対象ディレクトリで git push を実行してください。', copilot)

    head = git(cwd, 'rev-parse', '--verify', '--end-of-options', source + '^{commit}')
    if not head:
        return skip_review('CodeRabbit: 送信元をローカルのコミットとして解決できません。ブランチ名またはコミットを確認してください。', copilot)
    identity = git(cwd, 'rev-parse', '--symbolic-full-name', '--verify', '--end-of-options', source)
    if not identity.startswith('refs/'):
        identity = head
    common = Path(git(cwd, 'rev-parse', '--git-common-dir'))
    if not common.is_absolute():
        common = cwd / common
    marker = common / 'coderabbit-reviews' / hashlib.sha256(identity.encode()).hexdigest()
    try:
        marker.parent.mkdir(exist_ok=True)
    except OSError:
        return skip_review('CodeRabbit: レビュー記録の保存先を作成できません。git ディレクトリの権限を確認してください。', copilot)
    reviewed, reviewed_at = '', 0
    try:
        reviewed, *rest = marker.read_text().split()
        reviewed_at = int(rest[0]) if rest else 0
    except (OSError, ValueError):
        pass
    if reviewed == head:
        return 0
    args = ['coderabbit', 'review', '--committed']
    # rebase や force push で前回の HEAD が祖先でなくなったら、増分ではなく全体をレビューする。
    if reviewed and subprocess.run(['git', '-C', str(cwd), 'merge-base', '--is-ancestor', reviewed, head]).returncode == 0:
        args += ['--base-commit', reviewed]
        # スキップしてもマーカーは更新しない。小さい変更も次のレビューに累積して必ず対象になる。
        # gh pr create は最後の関門なので間引かない。
        if words[:2] == ['git', 'push']:
            numstat = git(cwd, 'diff', '--numstat', reviewed, head)
            changed = sum(int(n) for line in numstat.splitlines() for n in line.split('\t')[:2] if n.isdigit())
            min_lines = int(os.environ.get('CODERABBIT_SKIP_LINES', '50'))
            min_seconds = int(os.environ.get('CODERABBIT_SKIP_MINUTES', '10')) * 60
            if changed < min_lines or time.time() - reviewed_at < min_seconds:
                print(f'CodeRabbit: 前回レビューからの変更が小さい、または直後のためスキップします（{changed} 行）。', file=sys.stderr)
                return 0
    print(f'Reviewing with CodeRabbit CLI... {source} ({head[:12]})', file=sys.stderr)
    try:
        with review_checkout(cwd, head) as checkout:
            result = subprocess.run(args, cwd=checkout, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    except (OSError, RuntimeError) as error:
        return skip_review(f'CodeRabbit: レビュー用 worktree を準備・実行できませんでした: {error}', copilot)
    # exit 1 は「一部のファイルしかレビューできなかった」場合にも指摘を出力して返る。
    # 未完了扱いにすると指摘が agent に届かず、マーカーも残らず毎回ブロックされるため、
    # 出力があれば通常の指摘と同じく情報として返し、マーカーを更新する。
    if result.returncode and not (result.returncode == 1 and result.stdout.strip()):
        output = result.stdout or '(CLI output unavailable)'
        print(f'CodeRabbit review failed (exit {result.returncode}). レビューは未完了です。push / PR 作成は続行します。', file=sys.stderr)
        print(output, file=sys.stderr)
        return 0
    try:
        marker.write_text(f'{head} {int(time.time())}\n')
    except OSError:
        pass
    output = result.stdout
    return report(output or 'CodeRabbit review completed.', copilot)


if __name__ == '__main__':
    sys.exit(main())
