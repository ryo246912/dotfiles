import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('hook', Path(__file__).resolve().parents[1] / 'coderabbit-review.py')
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)
real_run = subprocess.run
reviews = []
review_exit = 0
cli_available = True
def run(args, **kwargs):
    if args[0] == 'coderabbit':
        reviews.append(hook.git(kwargs['cwd'], 'rev-parse', 'HEAD'))
        return subprocess.CompletedProcess(args, review_exit, 'No findings\n')
    return real_run(args, **kwargs)

def invoke(repo, command, copilot=False, blocked=False):
    event = {'cwd': str(repo), 'toolArgs' if copilot else 'tool_input': {'command': command}}
    out, err = io.StringIO(), io.StringIO()
    with patch.object(sys, 'stdin', io.StringIO(json.dumps(event))), patch.object(sys, 'argv', ['hook']), patch.object(hook.shutil, 'which', return_value='/fake/coderabbit' if cli_available else None), patch.object(hook.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = hook.main()
    if blocked:
        if copilot:
            assert code == 0
            result = json.loads(out.getvalue())
            assert result['permissionDecision'] == 'deny'
            return result['permissionDecisionReason']
        assert code == 2, (command, code, out.getvalue())
        return err.getvalue()
    assert code == 0, (command, code, err.getvalue())
    if out.getvalue() and not copilot:
        result = json.loads(out.getvalue())['hookSpecificOutput']
        assert result['hookEventName'] == 'PreToolUse'
        assert 'permissionDecision' not in result
        return result['additionalContext']
    return out.getvalue()

with tempfile.TemporaryDirectory() as tmp:
    repo = Path(tmp)
    def git(*args):
        return real_run(['git', '-C', tmp, *args], check=True, capture_output=True, text=True).stdout.strip()
    git('init')
    git('config', 'user.email', 'test@example.com')
    git('config', 'user.name', 'Test')
    (repo / '.coderabbit.yaml').write_text('{}\n')
    git('add', '.')
    git('commit', '-m', 'first')
    first = git('rev-parse', 'HEAD')
    (repo / 'file').write_text('second\n')
    git('add', '.')
    git('commit', '-m', 'second')
    head = git('rev-parse', 'HEAD')
    assert 'No findings' in invoke(repo, f'git -C {tmp} push origin {first}:other')
    assert reviews == [first]
    assert git('rev-parse', 'HEAD') == head
    assert len(git('worktree', 'list', '--porcelain').split('worktree ')) == 2
    assert invoke(repo, f'git push origin {first}:other') == ''  # review cache
    commands = [
        'git push origin HEAD:other; echo done',
        f'cd {tmp} && git push origin HEAD:other; echo done; tail -n 1 log',
        f'echo start; cd {tmp}; git push origin HEAD:other > log 2>&1',
        'git -c push.default=current push origin HEAD:other',
        f'git -C {tmp} push origin {first}:other',
        'git push origin HEAD:other; echo "$STATUS"',
    ]
    for copilot in (False, True):
        for command in commands:
            for marker in (repo / '.git/coderabbit-reviews').iterdir():
                marker.unlink()
            count = len(reviews)
            assert 'No findings' in invoke(repo, command, copilot), command
            assert len(reviews) == count + 1, command
            assert reviews[-1] == (first if first in command else head), command
        for command in ('git push origin "$SOURCE":other',
                        'git push origin HEAD:one HEAD:two',
                        'git push origin --delete other',
                        'git commit -m next && git push origin HEAD:other',
                        'git push origin HEAD:one; git push origin HEAD:two'):
            count = len(reviews)
            assert '操作を停止' in invoke(repo, command, copilot, blocked=True)
            assert len(reviews) == count
    # Small changes immediately after review are reviewed by default too.
    invoke(repo, 'git push origin HEAD:other')
    (repo / 'file').write_text('third\n')
    git('add', '.')
    git('commit', '-m', 'small follow-up')
    count = len(reviews)
    assert 'No findings' in invoke(repo, 'git push origin HEAD:other')
    assert len(reviews) == count + 1
    # Real linked worktree and a branch whose source differs from current HEAD.
    other = repo / 'linked'
    git('-c', 'core.hooksPath=/dev/null', 'worktree', 'add', '-b', 'other-source', str(other), first)
    for marker in (repo / '.git/coderabbit-reviews').iterdir():
        marker.unlink()
    assert 'No findings' in invoke(repo, f'cd {other} && git push origin HEAD:destination; echo done')
    assert reviews[-1] == first
    for marker in (repo / '.git/coderabbit-reviews').iterdir():
        marker.unlink()
    assert 'No findings' in invoke(repo, 'git push origin other-source:destination')
    assert reviews[-1] == first
    for copilot in (False, True):
        for review_exit in (1, 2):
            for marker in (repo / '.git/coderabbit-reviews').iterdir():
                marker.unlink()
            assert '操作を停止' in invoke(repo, 'git push origin HEAD:other', copilot, blocked=True)
            assert not list((repo / '.git/coderabbit-reviews').iterdir())
        review_exit = 0
        cli_available = False
        assert 'CLI が見つかりません' in invoke(repo, 'git push origin HEAD:other', copilot, blocked=True)
        cli_available = True
print('PASS: actual source review, compound commands, both hook formats, required review failures and unresolved targets, cache, worktree cleanup, and small follow-up')
