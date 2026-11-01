#!/usr/bin/env python3
"""PreToolUse review for literal git push / gh pr create commands, without eval."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time


def block(reason, copilot):
    if copilot:
        print(json.dumps({'permissionDecision': 'deny', 'permissionDecisionReason': reason}))
        return 0
    print(reason, file=sys.stderr)
    return 2


def git(cwd, *args):
    result = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ''


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
        # Global git options alter the repository or config. Detect, then reject them below.
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
    if words[:2] != ['git', 'push'] and words[:3] != ['gh', 'pr', 'create']:
        return block('CodeRabbit: git のグローバルオプションを外し、対象ディレクトリで git push を実行してください。', copilot)
    cwd = Path(tool.get('workdir') or event.get('cwd') or os.getcwd())
    if not cwd.is_absolute():
        cwd = Path.cwd() / cwd
    compound = False
    # Only a literal leading cd may precede the target. Commits and other mutations must run separately.
    if len(groups) == 2 and len(groups[0]) == 2 and groups[0][0] == 'cd' and separators == ['&&']:
        directory = groups[0][1]
        if directory.startswith('-') or any(c in directory for c in '$`~'):
            return block('CodeRabbit: cd を別の呼び出しで実行してから push / PR 作成を実行してください。', copilot)
        cwd = cwd / directory
    elif len(groups) != 1 or separators:
        # An unknown directory change cannot be assumed to target this repository.
        if any(g[:1] == ['cd'] for g in groups):
            return block('CodeRabbit: cd と push / PR 作成を別の呼び出しに分けてください。', copilot)
        compound = True

    repo = git(cwd, 'rev-parse', '--show-toplevel')
    if not repo or not (Path(repo) / '.coderabbit.yaml').is_file():
        return 0
    cwd = Path(repo)
    if compound:
        return block('CodeRabbit: commit・複合コマンドと push / PR 作成を別の呼び出しに分けてください。', copilot)
    if expansion:
        return block('CodeRabbit: 展開やコマンド置換を含めず、push / PR 作成を単独で実行してください。', copilot)
    head = git(cwd, 'rev-parse', '--verify', 'HEAD')
    if not head:
        return 0
    if words[:2] == ['git', 'push']:
        positional = []
        flags = {'-u', '--set-upstream', '-f', '--force', '--force-with-lease', '--force-if-includes',
                 '-v', '--verbose', '-q', '--quiet', '--no-verify', '-n', '--dry-run', '--porcelain',
                 '--atomic', '--progress', '--thin', '--no-thin', '-4', '--ipv4', '-6', '--ipv6'}
        for word in words[2:]:
            if word in flags or word.startswith('--force-with-lease='):
                continue
            if word.startswith('-'):
                return block('CodeRabbit: 複数 ref や未対応オプションの push は対象を確定できません。現在の HEAD を明示して push してください。', copilot)
            positional.append(word)
        if len(positional) > 2:
            return block('CodeRabbit: 一度に複数 ref を push せず、現在の HEAD を指定してください。', copilot)
        branch = git(cwd, 'symbolic-ref', '--quiet', '--short', 'HEAD')
        remote = (positional[0] if positional else
                  git(cwd, 'config', 'branch.' + branch + '.pushRemote') or
                  git(cwd, 'config', 'remote.pushDefault') or
                  git(cwd, 'config', 'branch.' + branch + '.remote') or 'origin')
        if (git(cwd, 'config', '--bool', 'remote.' + remote + '.mirror') == 'true' or
                git(cwd, 'config', '--bool', 'push.followTags') == 'true'):
            return block('CodeRabbit: mirror / followTags の push 設定を無効にし、現在の HEAD だけを送信してください。', copilot)
        if len(positional) == 2:
            source = positional[1].lstrip('+').split(':', 1)[0]
            if not source or git(cwd, 'rev-parse', '--verify', source + '^{commit}') != head:
                return block('CodeRabbit: 現在の HEAD 以外はレビュー対象外です。対象ブランチを checkout してから push してください。', copilot)
        elif (git(cwd, 'config', '--get-all', 'remote.' + remote + '.push') or
                git(cwd, 'config', 'push.default') not in ('', 'simple', 'current', 'upstream', 'nothing')):
            return block('CodeRabbit: push 設定から送信対象を確定できません。git push <remote> HEAD:<branch> と明示してください。', copilot)
    elif words[:3] == ['gh', 'pr', 'create']:
        args = words[3:]
        for i, word in enumerate(args):
            if word in ('--repo', '-R') or word.startswith('--repo=') or word.startswith('-R'):
                return block('CodeRabbit: --repo を使わず、対象リポジトリで PR を作成してください。', copilot)
            source = None
            if word in ('--head', '-H'):
                source = args[i + 1] if i + 1 < len(args) else ''
            elif word.startswith('--head='):
                source = word.split('=', 1)[1]
            elif word.startswith('-H'):
                source = word[2:]
            if source is not None and (':' in source or not source or git(cwd, 'rev-parse', '--verify', source + '^{commit}') != head):
                return block('CodeRabbit: 現在の HEAD のブランチで PR を作成してください。', copilot)
    else:
        return block('CodeRabbit: git のグローバルオプションを外し、対象ディレクトリで git push を実行してください。', copilot)

    marker = Path(git(cwd, 'rev-parse', '--git-path', 'coderabbit-reviewed'))
    if not marker.is_absolute():
        marker = cwd / marker
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
    print('Reviewing with CodeRabbit CLI...', file=sys.stderr)
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        output = result.stdout or '(CLI output unavailable)'
        print(f'CodeRabbit review failed (exit {result.returncode}). レビューは未完了です。push / PR 作成は続行します。', file=sys.stderr)
        print(output, file=sys.stderr)
        return 0
    try:
        marker.write_text(f'{head} {int(time.time())}\n')
    except OSError:
        pass
    output = result.stdout
    return block(output or 'CodeRabbit review completed. 結果を確認してから再実行してください。', copilot)


if __name__ == '__main__':
    sys.exit(main())
