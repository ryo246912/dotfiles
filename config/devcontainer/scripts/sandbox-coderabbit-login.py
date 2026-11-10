#!/usr/bin/env python3
"""Select a sandbox and forward its CodeRabbit browser callback over SSH."""
import argparse
import json
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs, urlsplit
import webbrowser


def login_lines(stream, timeout):
    """Bound the login wait even when SSH keeps stdout open without new events."""
    lines = queue.Queue()

    def read():
        try:
            for line in stream:
                lines.put(line)
        finally:
            lines.put(None)

    threading.Thread(target=read, daemon=True).start()
    deadline = time.monotonic() + timeout
    while True:
        try:
            line = lines.get(timeout=max(0, deadline - time.monotonic()))
        except queue.Empty:
            raise ValueError('CodeRabbit のログインがタイムアウトしました。ブラウザーの callback 接続を確認して再実行してください。') from None
        if line is None:
            return
        yield line


def callback_forward(auth_url):
    """Use the CLI's actual redirect, never a guessed port or custom-scheme fallback."""
    if not isinstance(auth_url, str) or not auth_url:
        raise ValueError('CLI からログイン URL を取得できませんでした。')
    login = urlsplit(auth_url)
    if login.scheme != 'https' or login.port not in (None, 443) or login.hostname not in ('app.coderabbit.ai', 'app.eu.coderabbit.ai') or login.username or login.password:
        raise ValueError('CodeRabbit のログイン URL が想定外です。CLI のバージョンを確認してください。')
    redirects = parse_qs(login.query).get('redirect_uri', [])
    if len(redirects) != 1:
        raise ValueError('CLI のログイン URL に callback がありません。CLI を更新してください。')
    callback = urlsplit(redirects[0])
    if callback.scheme != 'http' or callback.hostname not in ('localhost', '127.0.0.1', '::1') or not callback.port or callback.username or callback.password:
        raise ValueError('callback はポート番号付きの localhost URL が必要です。')
    host = '[::1]' if callback.hostname == '::1' else callback.hostname
    return f'{host}:{callback.port}:{host}:{callback.port}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sandbox', nargs='?', help='省略すると fzf で選択')
    parser.add_argument('--region', choices=['us', 'eu'], default='us')
    parser.add_argument('--timeout', type=float, default=300, help='ログイン待機の上限秒数（既定: 300）')
    args = parser.parse_args()
    if not 0 < args.timeout < float('inf'):
        parser.error('--timeout は正の有限数が必要です')
    for cmd in ['sbx', 'ssh'] + ([] if args.sandbox else ['fzf']):
        if not shutil.which(cmd):
            parser.error(f'{cmd} が必要です')
    listing = subprocess.check_output(['sbx', 'ls', '--json'], text=True)
    sandboxes = json.loads(listing)
    if isinstance(sandboxes, dict):
        sandboxes = sandboxes['sandboxes']
    names = [item['name'] for item in sandboxes]
    if not names:
        raise ValueError('sandbox がありません。先に sbx-agent で作成してください。')
    sandbox = args.sandbox
    if not sandbox:
        selected = subprocess.run(
            ['fzf', '--prompt=sandbox> ', '--header=CodeRabbit にログインする sandbox を選択'],
            input='\n'.join(names) + '\n', capture_output=True, text=True,
        )
        if selected.returncode:
            return selected.returncode
        sandbox = selected.stdout.strip()
    if sandbox not in names:
        raise ValueError('選択した sandbox が一覧にありません。')
    subprocess.run(['sbx', 'setup', 'ssh'], check=True)
    host = f'{sandbox}.sbx'
    print(f'{sandbox}: CodeRabbit のブラウザーログインを開始します。', flush=True)
    with tempfile.TemporaryDirectory(prefix='sbx-cr-') as tmp:
        control = str(Path(tmp) / 'ssh')
        ssh = ['ssh', '-S', control]
        command = ssh + ['-M', '-o', 'ControlPersist=no', '--', host,
                         'coderabbit', 'auth', 'login', '--agent', '--no-browser', '--region', args.region]
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True)
        authenticated = False
        forwarded = None
        try:
            for line in login_lines(process.stdout, args.timeout):
                try:
                    event = json.loads(line)
                except ValueError:
                    if line.strip():
                        print(line.rstrip(), file=sys.stderr)
                    continue
                if not isinstance(event, dict):
                    continue
                if event.get('type') == 'error' or event.get('status') in ('authentication_failed', 'automatic_login_failed'):
                    raise ValueError(event.get('message') or 'CodeRabbit のログインに失敗しました。')
                if event.get('status') == 'awaiting_browser_auth':
                    url = event.get('authUrl', '')
                    forward = callback_forward(url)
                    if forwarded is not None and forwarded != forward:
                        raise ValueError('ログイン中に callback が変更されました。再実行してください。')
                    if forwarded is None:
                        subprocess.run(ssh + ['-O', 'forward', '-o', 'ExitOnForwardFailure=yes',
                                              '-L', forward, '--', host], check=True)
                        forwarded = forward
                        print('callback の転送を開始しました。ブラウザーで認証してください。', flush=True)
                        if not webbrowser.open(url):
                            print(f'ブラウザーを開けませんでした。次の URL を開いてください:\n{url}', flush=True)
                if event.get('status') == 'authenticated' or event.get('authenticated') is True:
                    authenticated = True
                    # SSH can wait for browser keep-alive/forwarding channels after
                    # the remote CLI exits. Do not wait for EOF after success;
                    # finally closes the master and its forwarding channels.
                    break
            if not authenticated:
                rc = process.wait(timeout=5)
                if rc:
                    return rc
                raise ValueError('CLI の認証成功を確認できませんでした。')
            print('CodeRabbit にログインしました。callback の転送を終了します。')
            return 0
        finally:
            if process.poll() is None:
                try:
                    subprocess.run(ssh + ['-O', 'exit', '--', host], stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, timeout=5, check=False)
                    process.terminate()
                except (OSError, subprocess.TimeoutExpired):
                    process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            process.stdout.close()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(1)
