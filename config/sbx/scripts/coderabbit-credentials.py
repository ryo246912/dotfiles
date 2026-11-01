#!/usr/bin/env python3
"""Provision a sandbox-local CodeRabbit key without putting it in host argv/files."""
import argparse
import os
from pathlib import Path
import subprocess
import sys


INSTALL = r'''
import os, pathlib, sys
key = sys.stdin.buffer.read().strip()
if not key or b'\n' in key or b'\r' in key or b'\0' in key:
    sys.exit('CodeRabbit credential must be a nonempty single line')
path = '/etc/coderabbit-api-key'
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, 'wb') as f:
    os.fchmod(f.fileno(), 0o600)
    os.fchown(f.fileno(), 1000, 1000)
    f.write(key + b'\n')
persistent = pathlib.Path('/etc/sandbox-persistent.sh')
line = 'if [ -r /etc/coderabbit-api-key ]; then export CODERABBIT_API_KEY="$(cat /etc/coderabbit-api-key)"; fi'
existing = persistent.read_text() if persistent.exists() else ''
if line not in existing.splitlines():
    with persistent.open('a') as f:
        f.write('\n' + line + '\n')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', required=True, choices=['private', 'work3'])
    args = parser.parse_args()
    sandbox = os.environ.get('SBX_SANDBOX_NAME')
    if not sandbox:
        print('CodeRabbit: SBX_SANDBOX_NAME が未設定です。sbx env の postCreate から実行してください。', file=sys.stderr)
        return 1
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'fnox/config.toml'
    try:
        result = subprocess.run(
            ['fnox', '--config', str(config), 'get', '--profile', args.profile, 'CODERABBIT_API_KEY'],
            cwd=Path.home(), capture_output=True,
        )
        key = result.stdout.strip()
        if result.returncode or not key or any(c in key for c in (b'\n', b'\r', b'\0')) or key == b'proxy-managed':
            print('CodeRabbit: fnox から有効な形式のキーを取得できませんでした。profile の設定を確認してください。', file=sys.stderr)
            return 1
        installed = subprocess.run(
            ['sbx', 'exec', '-i', '-u', 'root', sandbox, 'python3', '-c', INSTALL],
            input=key, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        if installed.returncode:
            print('CodeRabbit: sandbox 内へのキー配置に失敗しました。sandbox の状態を確認してください。', file=sys.stderr)
            return 1
    except OSError:
        print('CodeRabbit: fnox または sbx を実行できませんでした。ホストの PATH を確認してください。', file=sys.stderr)
        return 1
    print('CodeRabbit: sandbox 専用の API key を配置しました。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
