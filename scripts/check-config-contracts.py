#!/usr/bin/env python3
"""Check the repository's version and formatter scheduling contracts (Python 3.11+)."""

import fnmatch
import json
from pathlib import Path
import sys
import tomllib


def load_toml(path):
    with path.open("rb") as stream:
        return tomllib.load(stream)


def check_versions(root):
    errors = []
    versions = [load_toml(root / path)["tools"]["npm:oxlint"] for path in
                ("mise.toml", "config/mise/config.toml")]
    if len(set(versions)) != 1:
        errors.append("oxlint-version: project と global の pin が一致しません")
    schema = json.loads((root / "config/devcontainer/lint/oxlint.json").read_text())["$schema"]
    expected = ("https://raw.githubusercontent.com/oxc-project/oxc/"
                f"oxlint_v{versions[0]}/npm/oxlint/configuration_schema.json")
    if schema != expected:
        errors.append("oxlint-schema: schema URL を mise の pin と揃えてください")
    return errors


def check_tasks(tasks):
    """Detect repeated scheduling through depends and sequential run-task entries."""
    errors = []

    def dependencies(name):
        result = []
        for item in tasks[name].get("depends", []):
            if not isinstance(item, str):
                errors.append(f"task-dependency: {name}: 配列形式の依存は検査未対応です")
                continue
            matches = sorted(fnmatch.filter(tasks, item))
            if not matches:
                errors.append(f"task-dependency: {name}: {item} の対象がありません")
            result.extend(matches)
        return result

    def children(name):
        result = dependencies(name)
        run = tasks[name].get("run", [])
        if isinstance(run, list):
            for step in run:
                if isinstance(step, dict) and "task" in step:
                    target = step["task"]
                    if target not in tasks:
                        errors.append(f"task-dependency: {name}: {target} が未定義です")
                    else:
                        result.append(target)
        return result

    def visit(name, ancestors):
        if name in ancestors:
            errors.append(f"task-cycle: {' -> '.join((*ancestors, name))}")
            return set()
        # mise deduplicates depends nodes, but a task invoked from run can be
        # executed again alongside a depends branch. Check those two paths.
        deps = dependencies(name)
        sequential = children(name)[len(deps):]
        dep_closure = set()
        for child in deps:
            dep_closure |= visit(child, (*ancestors, name)) | {child}
        run_closure = set()
        for child in sequential:
            run_closure |= visit(child, (*ancestors, name)) | {child}
        overlap = dep_closure & run_closure
        if overlap:
            errors.append(f"task-duplicate: {name}: depends と run が重複: {', '.join(sorted(overlap))}")
        return dep_closure | run_closure

    # Check direct siblings as well: fix:* can schedule both a wrapper and
    # the wrapper's run-task entries concurrently.
    for name in tasks:
        deps = dependencies(name)
        for child in deps:
            nested = set()
            pending = [child]
            seen = set()
            while pending:
                current = pending.pop()
                if current in seen:
                    continue
                seen.add(current)
                run = tasks[current].get("run", [])
                for step in run if isinstance(run, list) else []:
                    if isinstance(step, dict) and step.get("task") in tasks:
                        nested.add(step["task"])
                        pending.append(step["task"])
                pending.extend(dependencies(current))
            overlap = (set(deps) - {child}) & nested
            if overlap:
                errors.append(f"task-duplicate: {name}: {child} の内部タスクも直接起動: {', '.join(sorted(overlap))}")
        visit(name, ())
    return sorted(set(errors))


def check(root):
    errors = check_versions(root)
    for directory in ("tasks", "config/mise/tasks"):
        tasks = {}
        for path in sorted((root / directory).glob("*.toml")):
            for name, definition in load_toml(path).items():
                if name in tasks:
                    errors.append(f"task-definition: {directory}: {name} が重複しています")
                tasks[name] = definition
        errors.extend(f"{directory}: {error}" for error in check_tasks(tasks))
    return errors


def main():
    root = Path(__file__).resolve().parents[1]
    try:
        errors = check(root)
    except (OSError, ValueError, KeyError) as exc:
        print(f"config-contract: {exc}", file=sys.stderr)
        return 1
    for error in errors:
        print(error, file=sys.stderr)
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
