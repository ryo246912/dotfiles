"""知見のfrontmatterだけを一覧し、必要な本文を選べるようにする。追加依存なし。

    python3 list_lessons.py --config /path/pr-reviewer-behavior/config.md --repo owner/repo --environment local

frontmatterの値はJSON互換のスカラーまたは1行配列。本文は出力しない。
"""

import argparse
import json
import re
from pathlib import Path


def metadata(path: Path) -> dict:
    result = {}
    size = 0
    with path.open(encoding="utf-8") as stream:
        if stream.readline().strip() != "---":
            raise ValueError("frontmatterの開始がない")
        for index, line in enumerate(stream):
            size += len(line.encode("utf-8"))
            if index >= 128 or size > 32768:
                raise ValueError("frontmatterが長すぎる")
            if line.strip() == "---":
                return result
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            key, separator, value = line.partition(":")
            if not separator or not re.fullmatch(r"[a-z_]+", key) or key in result:
                raise ValueError("frontmatterのキーが不正・重複")
            try:
                result[key] = json.loads(value)
            except ValueError:
                raise ValueError("frontmatterの値は引用符付き文字列・数値・1行配列で記述する") from None
    raise ValueError("frontmatterの終端がない")


def lesson_index(config: Path, repository: str, environment: str | None = None, query: str = "") -> dict:
    components = repository.split("/")
    if len(components) != 2 or any(
        part in {".", ".."} or not re.fullmatch(r"[A-Za-z0-9_.-]+", part) for part in components
    ):
        raise ValueError("repoはowner/repoで指定する")
    parent = config.resolve().parent
    root = (parent / "lessons").resolve()
    if not root.is_relative_to(parent):
        raise ValueError("lessonsの実体が設定ディレクトリの外にある")
    directory = root.joinpath(*components)
    if not directory.resolve().is_relative_to(root):
        raise ValueError("repoの知見ディレクトリがlessonsの外にある")
    rows, warnings = [], []
    paths = sorted(path for path in directory.iterdir() if path.suffix == ".md") if directory.exists() else []
    for path in paths:
        try:
            if not path.resolve().is_relative_to(root):
                raise ValueError("知見ファイルの実体がlessonsの外にある")
            item = metadata(path)
            for key in ("title", "summary", "repository", "environment", "status", "created_at", "updated_at"):
                if not isinstance(item.get(key), str) or not item[key].strip():
                    raise ValueError(f"frontmatterの{key}は空でない文字列にする")
            if type(item.get("schema_version")) is not int or item["schema_version"] != 1:
                raise ValueError("未対応のschema_version")
            if item["environment"] not in {"local", "staging", "all"} or item["status"] not in {"active", "retired"}:
                raise ValueError("environmentまたはstatusが不正")
            for key in ("tags", "evidence"):
                if not isinstance(item.get(key), list) or any(not isinstance(value, str) for value in item[key]):
                    raise ValueError(f"frontmatterの{key}は文字列配列にする")
            if item["repository"].casefold() != repository.casefold():
                raise ValueError("配置先とrepositoryが一致しない")
            if item["status"] == "retired":
                continue
            if environment and item["environment"] not in {environment, "all"}:
                continue
            search = " ".join([item["title"], item["summary"], *item["tags"]]).casefold()
            if query.casefold() not in search:
                continue
            rows.append({"path": str(path), **{key: item[key] for key in (
                "title", "summary", "environment", "tags", "updated_at"
            )}})
        except (ValueError, OSError, UnicodeError) as error:
            warnings.append({"path": str(path), "reason": str(error)})
    return {"lessons": rows, "warnings": warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--environment", choices=("local", "staging"))
    parser.add_argument("--query", default="")
    args = parser.parse_args()
    try:
        result = lesson_index(args.config, args.repo, args.environment, args.query)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
