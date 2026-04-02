"""
autoharness スキル用テンプレート
このファイルは /autoharness-init の Step 3 で参考として読み込まれ、
プロジェクト固有の内容を埋めた .claude/rules/harness_check.py が生成される。

Claude Code はこのファイルを直接実行しない。
生成される harness_check.py のテンプレートとして使用する。
"""

import subprocess
import sys
import json
from pathlib import Path

# プロジェクトルートを自動検出（.claude/rules/ から3階層上）
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# ---------------------------------------------------------------
# プロジェクト固有の設定（/autoharness-init 時に自動入力される）
# ---------------------------------------------------------------
CHECKS = {
    # 例: "typecheck": "npx tsc --noEmit"
    # 例: "typecheck": "mypy ."
    "typecheck": None,

    # 例: "lint": "npx eslint ."
    # 例: "lint": "ruff check ."
    "lint": None,

    # 例: "test": "npm test"
    # 例: "test": "pytest"
    "test": None,

    # 例: "build": "npm run build"
    "build": None,
}

# Noneのチェックはスキップする
CHECKS = {k: v for k, v in CHECKS.items() if v is not None}

# ---------------------------------------------------------------
# 実行ロジック（変更不要）
# ---------------------------------------------------------------

def run_check(name: str, cmd: str, files: list[str] | None = None) -> dict:
    """コマンドを実行して結果を返す"""
    # ファイル指定可能なチェック（lint, typecheck）はファイルを引数に追加
    full_cmd = cmd
    if files and name in ("lint", "typecheck"):
        full_cmd = f"{cmd} {' '.join(files)}"

    try:
        result = subprocess.run(
            full_cmd,
            shell=True,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
        )
        passed = result.returncode == 0
        return {
            "passed": passed,
            "command": full_cmd,
            "stdout": result.stdout.strip()[-2000:] if result.stdout else "",
            "stderr": result.stderr.strip()[-2000:] if result.stderr else "",
            "returncode": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "passed": False,
            "command": full_cmd,
            "stdout": "",
            "stderr": "タイムアウト（60秒）",
            "returncode": -1,
        }
    except Exception as e:
        return {
            "passed": False,
            "command": full_cmd,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1,
        }


def main():
    files = sys.argv[1:] if len(sys.argv) > 1 else []

    if "--help" in files or "-h" in files:
        print("使い方: python .claude/rules/harness_check.py [ファイルパス...]")
        print("")
        print("  引数なし: プロジェクト全体をチェック")
        print("  ファイル指定: そのファイルに対してlint/typecheckを実行")
        print("")
        print("設定済みチェック:")
        for name, cmd in CHECKS.items():
            print(f"  {name}: {cmd}")
        sys.exit(0)

    if not CHECKS:
        print(json.dumps({
            "passed": False,
            "error": "チェックが設定されていません。/autoharness-init を実行してください。",
            "results": {}
        }, indent=2, ensure_ascii=False))
        sys.exit(1)

    results = {}
    for name, cmd in CHECKS.items():
        print(f"[autoharness] {name} を実行中...", file=sys.stderr)
        results[name] = run_check(name, cmd, files)

    passed = all(r["passed"] for r in results.values())
    failed = [name for name, r in results.items() if not r["passed"]]

    output = {
        "passed": passed,
        "failed_checks": failed,
        "results": results,
    }

    print(json.dumps(output, indent=2, ensure_ascii=False))
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()