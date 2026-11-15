"""知見のfrontmatterだけを一覧し、必要な本文を選べるようにする。追加依存なし。

    python3 list_lessons.py --repo owner/repo --environment local

frontmatterの値はJSON互換のスカラーまたは1行配列。本文は出力しない。
pathはagent-lessons基準の相対POSIXパス（behavor/...）を返す。
--configは旧保存先の移行確認専用（lessons/...を返す）。
"""

import argparse
import json
import re
from pathlib import Path


class UnsupportedSchemaVersionError(ValueError):
    """新しい形式の知見を読み飛ばした一覧は返さない。"""


def metadata(path: Path) -> dict:
    result = {}
    with path.open("rb") as stream:
        opening = stream.readline(6)
        if opening.strip() != b"---":
            raise ValueError("frontmatterの開始がない")
        size = len(opening)
        for _ in range(128):
            raw = stream.readline(32768 - size + 1)
            if not raw:
                break
            size += len(raw)
            if size > 32768:
                raise ValueError("frontmatterが長すぎる")
            line = raw.decode("utf-8")
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
                raise ValueError(
                    "frontmatterの値は引用符付き文字列・数値・1行配列で記述する"
                ) from None
    raise ValueError("frontmatterの終端がない、または行数が多すぎる")


def repository_directories(root: Path, components: list[str]) -> list[Path]:
    """旧表記のディレクトリも検索し、repo境界をsymlinkで越えない。"""
    directories = [root] if root.exists() else []
    for component in components:
        matches = []
        for parent in directories:
            for candidate in parent.iterdir():
                if candidate.name.casefold() != component.casefold():
                    continue
                if candidate.is_symlink():
                    raise ValueError("owner/repoの知見ディレクトリにsymlinkは使えない")
                if not candidate.is_dir() or not candidate.resolve().is_relative_to(
                    root
                ):
                    raise ValueError("owner/repoの知見ディレクトリが不正")
                matches.append(candidate)
        directories = sorted(matches)
    return directories


def lesson_index(
    config: Path | None,
    repository: str,
    environment: str | None = None,
    query: str = "",
    *,
    lessons_dir: Path | None = None,
) -> dict:
    components = repository.split("/")
    if len(components) != 2 or any(
        part in {".", ".."} or not re.fullmatch(r"[A-Za-z0-9_.-]+", part)
        for part in components
    ):
        raise ValueError("repoはowner/repoで指定する")
    if config is not None and lessons_dir is not None:
        raise ValueError("--configと--lessons-dirは同時に指定できない")
    if config is not None:
        parent = config.resolve(strict=True).parent
        directory = parent / "lessons"
    else:
        directory = lessons_dir or Path.home() / ".local/share/agent-lessons/behavor"
        directory = directory.expanduser().absolute()
        if directory.name != "behavor":
            raise ValueError(
                "--lessons-dirはagent-lessonsのbehavorディレクトリを指定する"
            )
        parent = directory.parent.resolve(strict=True)
    root = directory.resolve()
    if root != parent / directory.name:
        raise ValueError("知見ルートのsymlinkで保存先を変更できない")
    if root.exists() and not root.is_dir():
        raise ValueError("知見ルートがディレクトリではない")
    prefix = directory.name
    directories = repository_directories(root, components)
    rows, warnings = [], []
    paths = sorted(
        (path, directory)
        for directory in directories
        for path in directory.iterdir()
        if path.suffix == ".md"
    )
    for path, directory in paths:
        relative_path = (Path(prefix) / path.relative_to(root)).as_posix()
        try:
            if (
                path.is_symlink()
                or not path.is_file()
                or path.resolve().parent != directory.resolve()
            ):
                raise ValueError("知見ファイルの実体が対象repoの外にある")
            item = metadata(path)
            version = item.get("schema_version")
            if type(version) is int and version > 1:
                raise UnsupportedSchemaVersionError(
                    f"{relative_path}: schema_version={version}は未対応。一覧取得を停止する"
                )
            for key in (
                "title",
                "summary",
                "repository",
                "environment",
                "status",
                "created_at",
                "updated_at",
            ):
                if not isinstance(item.get(key), str) or not item[key].strip():
                    raise ValueError(f"frontmatterの{key}は空でない文字列にする")
            if (
                type(item.get("schema_version")) is not int
                or item["schema_version"] != 1
            ):
                raise ValueError("未対応のschema_version")
            if item["environment"] not in {"local", "staging", "all"} or item[
                "status"
            ] not in {
                "active",
                "retired",
            }:
                raise ValueError("environmentまたはstatusが不正")
            for key in ("tags", "evidence"):
                if not isinstance(item.get(key), list) or any(
                    not isinstance(value, str) for value in item[key]
                ):
                    raise ValueError(f"frontmatterの{key}は文字列配列にする")
            if item["repository"].casefold() != repository.casefold():
                raise ValueError("配置先とrepositoryが一致しない")
            if item["status"] == "retired":
                continue
            if environment and item["environment"] not in {environment, "all"}:
                continue
            search = " ".join(
                [item["title"], item["summary"], *item["tags"]]
            ).casefold()
            if query.casefold() not in search:
                continue
            rows.append(
                {
                    "path": relative_path,
                    **{
                        key: item[key]
                        for key in (
                            "title",
                            "summary",
                            "environment",
                            "tags",
                            "updated_at",
                        )
                    },
                }
            )
        except UnsupportedSchemaVersionError:
            raise
        except (ValueError, OSError, UnicodeError) as error:
            warnings.append({"path": relative_path, "reason": str(error)})
    return {"lessons": rows, "warnings": warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--config", type=Path, help="移行確認用の旧config.md")
    source.add_argument(
        "--lessons-dir",
        type=Path,
        help="知見ルート（既定: ~/.local/share/agent-lessons/behavor）",
    )
    parser.add_argument("--repo", required=True)
    parser.add_argument("--environment", choices=("local", "staging"))
    parser.add_argument("--query", default="")
    args = parser.parse_args()
    try:
        result = lesson_index(
            args.config,
            args.repo,
            args.environment,
            args.query,
            lessons_dir=args.lessons_dir,
        )
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
