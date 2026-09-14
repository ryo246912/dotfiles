#!/usr/bin/env python3
"""prepare-dump-auth のregression。`mise run test:agentsview` から実行する。

このscriptはremoteのURIを「passwordを含まないURL」と「.pgpass」へ分け、URLが
sslrootcertでCAを指している場合はそのpathを別fileへ出す。呼び出し元
（agentsview.tomlのremote:dump）はfile名と中身に依存していて、passwordを
URLへ残すと処理一覧やlogへ載る。分け方をtableで持ち、scriptをそのまま起動して
出力fileを確かめる。
"""

import os
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

# 隣のdirectoryを指す（repository rootからの相対ではないので、このfileが
# どこから実行されてもよい）。
AGENTSVIEW = Path(__file__).resolve().parents[1]
SCRIPT = AGENTSVIEW / "executable_prepare-dump-auth"


def run(url, **extra):
    """remote dumpと同じ環境でscriptを動かし、出力fileを読む。"""

    with tempfile.TemporaryDirectory() as tmp:
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "AGENTSVIEW_DUMP_PG_URL": url,
            "AGENTSVIEW_DUMP_ALLOW_REMOTE": "yes",
            "AGENTSVIEW_DUMP_AUTH_DIR": tmp,
        }
        env.update(extra)
        proc = subprocess.run(
            [sys.executable, str(SCRIPT)], capture_output=True, text=True, env=env, check=False
        )
        files = {}
        modes = {}
        for path in sorted(Path(tmp).iterdir()):
            files[path.name] = path.read_text()
            modes[path.name] = path.stat().st_mode & 0o777
        return proc.returncode, proc.stderr, files, modes


cases = []


def case(name, url, *, rc=0, files=None, absent=(), stderr=None, env=None):
    """1 caseを登録する。filesは「file名 -> 期待する中身」。"""

    cases.append((name, url, rc, files or {}, absent, stderr, env or {}))


BASE = "postgres://ryo:pw%40word@remote.example:26257/agentsview"

# passwordはURLから外して.pgpassへ入れる（URLはlogへ出る）。
case(
    "password moves to pgpass",
    f"{BASE}?sslmode=verify-full",
    files={
        "url": "postgres://ryo@remote.example:26257/agentsview?sslmode=verify-full",
        "pgpass": "remote.example:26257:agentsview:ryo:pw@word\n",
    },
    absent=("sslrootcert",),
)
# URLがCAを指している場合はpathを別fileへ出し、URLからは落とす。
case(
    "sslrootcert goes to its own file",
    f"{BASE}?sslmode=verify-full&sslrootcert=/etc/ssl/private-ca.crt",
    files={
        "url": "postgres://ryo@remote.example:26257/agentsview?sslmode=verify-full",
        "sslrootcert": "/etc/ssl/private-ca.crt\n",
    },
)
# `system`はpathではないので渡さない（呼び出し元が既定のbundleを選ぶ）。
case(
    "sslrootcert=system is dropped",
    f"{BASE}?sslmode=verify-full&sslrootcert=system",
    files={"url": "postgres://ryo@remote.example:26257/agentsview?sslmode=verify-full"},
    absent=("sslrootcert",),
)
# 他のoptionはURLへ残す。
case(
    "other options stay on the url",
    f"{BASE}?sslmode=verify-full&application_name=agentsview&connect_timeout=10",
    files={
        "url": "postgres://ryo@remote.example:26257/agentsview"
        "?sslmode=verify-full&application_name=agentsview&connect_timeout=10"
    },
)
# .pgpassの区切りに使う文字はescapeする。
case(
    "pgpass escapes colons and backslashes",
    "postgres://ryo:a%3Ab%5Cc@remote.example:26257/agentsview",
    files={"pgpass": "remote.example:26257:agentsview:ryo:a\\:b\\\\c\n"},
)
# sslpasswordは鍵のpassphraseなので、分離できない形では受け取らない。
case(
    "sslpassword is rejected",
    f"{BASE}?sslpassword=secret",
    rc=1,
    stderr="must not contain sslpassword",
)
case("hostname is required", "postgres://ryo:pw@/agentsview", rc=1, stderr="must contain a hostname")
case("port is validated", "postgres://ryo:pw@remote.example:99999/agentsview", rc=1,
     stderr="invalid port")
# remoteを明示していない場合は、Fly proxy以外へ向けられない。
case(
    "remote requires the explicit flag",
    f"{BASE}?sslmode=verify-full",
    rc=1,
    stderr="must point to the local Fly proxy",
    env={"AGENTSVIEW_DUMP_ALLOW_REMOTE": "no"},
)

fails = 0
for name, url, rc, files, absent, stderr, env in cases:
    got_rc, got_err, got_files, modes = run(url, **env)
    problems = []
    if got_rc != rc:
        problems.append(f"rc {got_rc} != {rc} ({got_err.strip()[:80]})")
    if stderr and stderr not in got_err:
        problems.append(f"missing stderr {stderr!r}")
    for fname, want in files.items():
        if got_files.get(fname) != want:
            problems.append(f"{fname}: {got_files.get(fname)!r} != {want!r}")
    for fname in absent:
        if fname in got_files:
            problems.append(f"unexpected file {fname}")
    # passwordはURLへ残してはいけない（URLはtaskのlogへ出る）。個別のpasswordを
    # 文字列で探すのではなく、URLを解析してuserinfoのpassword部が空であることを見る。
    # URIの中ではpasswordはpercent encodeされるので（`pw@word`は`pw%40word`）、
    # 文字列一致では漏れを見落とす。
    if "url" in got_files:
        try:
            leaked = urllib.parse.urlsplit(got_files["url"].strip()).password
        except ValueError as exc:
            problems.append(f"url is not parseable: {exc}")
        else:
            if leaked:
                problems.append("url leaks the password")
    for fname, mode in modes.items():
        if mode != 0o600:
            problems.append(f"{fname} mode {oct(mode)} != 0o600")
    if problems:
        fails += 1
        print(f"FAIL {name}: {'; '.join(problems)}")
print(f"{len(cases) - fails}/{len(cases)} passed")
sys.exit(1 if fails else 0)
