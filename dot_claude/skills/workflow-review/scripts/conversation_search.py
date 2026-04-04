#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["bm25s==0.3.0"]
# ///
#
# Based on: https://eric-tramel.github.io/blog/2026-02-07-searchable-agent-memory/
# Original: MCP server by Eric Tramel. Adapted to standalone CLI for workflow-review skill.

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path


def _discover_jsonl_files(
    conversations_dir: Path,
    recent_days: int | None = None,
    project_filter: str | None = None,
) -> list[Path]:
    cutoff = time.time() - (recent_days * 86400) if recent_days else 0
    files: list[Path] = []
    for p in sorted(conversations_dir.rglob("*.jsonl")):
        if "/subagents/" in str(p) or "subagents" in p.parts:
            continue
        if project_filter:
            # project dir is the immediate parent of the JSONL file
            if project_filter not in p.parent.name:
                continue
        if recent_days and p.stat().st_mtime < cutoff:
            continue
        files.append(p)
    return files


def _parse_conversation(jsonl_path: Path) -> tuple[list[dict], dict]:
    session_id = jsonl_path.stem
    project = jsonl_path.parent.name
    turns: list[dict] = []
    slug = ""
    first_ts = ""
    last_ts = ""
    summary = ""

    current_user_text = ""
    current_assistant_text = ""
    current_tool_names: set[str] = set()
    current_ts = ""
    in_turn = False

    def _save_turn():
        nonlocal current_user_text, current_assistant_text, current_tool_names, current_ts
        if not current_user_text:
            return
        text_parts = [current_user_text, current_assistant_text]
        if current_tool_names:
            text_parts.append("tools: " + " ".join(sorted(current_tool_names)))
        turns.append({
            "text": "\n".join(text_parts),
            "turn_number": len(turns),
            "session_id": session_id,
            "project": project,
            "timestamp": current_ts,
            "tool_names": sorted(current_tool_names),
        })

    try:
        with open(jsonl_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except (json.JSONDecodeError, ValueError):
                    continue

                if record.get("slug") and not slug:
                    slug = record["slug"]

                ts = record.get("timestamp", "")
                if ts:
                    if not first_ts:
                        first_ts = ts
                    last_ts = ts

                msg_type = record.get("type")
                if msg_type not in ("user", "assistant"):
                    continue

                message = record.get("message", {})
                content = message.get("content")

                if msg_type == "user" and isinstance(content, str):
                    if in_turn:
                        _save_turn()
                    current_user_text = content
                    current_assistant_text = ""
                    current_tool_names = set()
                    current_ts = ts
                    in_turn = True
                    if not summary:
                        summary = content[:200]

                elif msg_type == "user" and isinstance(content, list):
                    continue

                elif msg_type == "assistant" and isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get("type") == "text":
                            current_assistant_text += block.get("text", "") + "\n"
                        elif block.get("type") == "tool_use":
                            name = block.get("name", "")
                            if name:
                                current_tool_names.add(name)

        if in_turn:
            _save_turn()

    except OSError:
        pass

    for turn in turns:
        turn["slug"] = slug

    metadata = {
        "slug": slug,
        "summary": summary,
        "first_timestamp": first_ts,
        "last_timestamp": last_ts,
        "turn_count": len(turns),
        "project": project,
    }

    return turns, metadata


def _build_index(files: list[Path]):
    import bm25s

    corpus: list[dict] = []
    conversations: dict[str, dict] = {}

    for jsonl_path in files:
        turns, metadata = _parse_conversation(jsonl_path)
        conversations[jsonl_path.stem] = metadata
        corpus.extend(turns)

    retriever = None
    if corpus:
        corpus_tokens = bm25s.tokenize([e["text"] for e in corpus], stopwords="en")
        retriever = bm25s.BM25()
        retriever.index(corpus_tokens)

    return corpus, retriever, conversations


def search(files: list[Path], query: str, top_k: int = 10) -> str:
    corpus, retriever, _convs = _build_index(files)

    if retriever is None or not corpus:
        return json.dumps({"results": [], "query": query, "total": 0}, indent=2)

    import bm25s

    query_tokens = bm25s.tokenize([query], stopwords="en")
    results, scores = retriever.retrieve(query_tokens, k=min(top_k, len(corpus)))

    search_results: list[dict] = []
    for i in range(results.shape[1]):
        doc_idx = results[0, i]
        score = float(scores[0, i])
        if score <= 0:
            continue
        entry = corpus[doc_idx]
        search_results.append({
            "session_id": entry["session_id"],
            "project": entry["project"],
            "slug": entry["slug"],
            "turn_number": entry["turn_number"],
            "score": round(score, 4),
            "snippet": entry["text"][:300],
        })

    return json.dumps({"results": search_results, "query": query, "total": len(search_results)}, indent=2)


PATTERNS: dict[str, dict[str, str]] = {
    "permission_fatigue": {
        "query": "permission denied approved allow",
        "detects": "Repeatedly approving the same tools",
    },
    "bash_for_file_ops": {
        "query": "bash cat grep find sed awk echo",
        "detects": "Bash used instead of dedicated tools (Read/Edit/Grep/Glob)",
    },
    "recurring_errors": {
        "query": "error retry failed traceback exception",
        "detects": "Recurring errors and retries",
    },
    "subagent_issues": {
        "query": "task subagent fork context denied",
        "detects": "Subagent context starvation or access failures",
    },
    "context_pressure": {
        "query": "compact context token limit",
        "detects": "Context window pressure and compaction events",
    },
    "glob_via_bash": {
        "query": "find . -name ls -la ls -r find / -type",
        "detects": "Using find/ls instead of Glob tool",
    },
    "grep_via_bash": {
        "query": "grep -r grep -n grep -i rg ripgrep",
        "detects": "Using shell grep/rg instead of Grep tool",
    },
    "edit_via_heredoc": {
        "query": "cat > << EOF tee sed -i awk -i",
        "detects": "Writing files via bash instead of Edit/Write tools",
    },
    "revert_churn": {
        "query": "revert undo restore original rollback go back previous",
        "detects": "Frequent reversals — poor planning or scope disagreement",
    },
    "clarification_loop": {
        "query": "what do you mean clarify which file which directory",
        "detects": "Excessive clarification — under-specified project context",
    },
    "debug_loop": {
        "query": "still failing same error tried that already doesn't work",
        "detects": "Stuck debugging loops",
    },
    "hallucinated_api": {
        "query": "doesn't exist no such attribute ImportError ModuleNotFoundError",
        "detects": "Claude using non-existent APIs",
    },
}


def patterns(files: list[Path], top_k: int = 5) -> str:
    corpus, retriever, _convs = _build_index(files)

    if retriever is None or not corpus:
        return json.dumps({"patterns": {}, "total_files": 0}, indent=2)

    import bm25s

    results_by_pattern: dict[str, list[dict]] = {}
    for name, info in PATTERNS.items():
        query_tokens = bm25s.tokenize([info["query"]], stopwords="en")
        results, scores = retriever.retrieve(query_tokens, k=min(top_k, len(corpus)))

        hits: list[dict] = []
        for i in range(results.shape[1]):
            doc_idx = results[0, i]
            score = float(scores[0, i])
            if score <= 0:
                continue
            entry = corpus[doc_idx]
            hits.append({
                "session_id": entry["session_id"],
                "project": entry["project"],
                "slug": entry["slug"],
                "turn_number": entry["turn_number"],
                "score": round(score, 4),
                "snippet": entry["text"][:300],
            })

        results_by_pattern[name] = {
            "detects": info["detects"],
            "hits": len(hits),
            "results": hits,
        }

    # Sort by hit count descending
    sorted_patterns = dict(
        sorted(results_by_pattern.items(), key=lambda x: x[1]["hits"], reverse=True)
    )

    return json.dumps({"patterns": sorted_patterns, "total_files": len(files)}, indent=2)


def stats(files: list[Path]) -> str:
    total_sessions = 0
    total_turns = 0
    tool_counter: Counter[str] = Counter()
    project_counter: Counter[str] = Counter()

    for jsonl_path in files:
        turns, metadata = _parse_conversation(jsonl_path)
        total_sessions += 1
        total_turns += len(turns)
        project_counter[metadata["project"]] += 1
        for turn in turns:
            for name in turn.get("tool_names", []):
                tool_counter[name] += 1

    return json.dumps(
        {
            "total_sessions": total_sessions,
            "total_turns": total_turns,
            "tool_frequency": dict(tool_counter.most_common()),
            "sessions_by_project": dict(project_counter.most_common()),
        },
        indent=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="BM25 search across Claude Code conversation transcripts")
    parser.add_argument("conversations_dir", help="Path to ~/.claude/projects")
    parser.add_argument("query", nargs="?", default=None, help="Search query (required for search mode)")
    parser.add_argument("--top-k", type=int, default=10, help="Max results (default 10)")
    parser.add_argument("--recent-days", type=int, default=None, help="Filter by file mtime (days)")
    parser.add_argument("--project", default=None, help="Filter by project dir name substring")
    parser.add_argument("--mode", choices=["search", "stats", "patterns"], default="search", help="Mode (default: search)")
    args = parser.parse_args()

    conv_dir = Path(args.conversations_dir).resolve()
    if not conv_dir.is_dir():
        print(f"Not a directory: {conv_dir}", file=sys.stderr)
        sys.exit(1)

    files = _discover_jsonl_files(conv_dir, args.recent_days, args.project)

    if args.mode == "stats":
        print(stats(files))
    elif args.mode == "patterns":
        print(patterns(files, args.top_k))
    else:
        if not args.query:
            print("Error: query is required for search mode", file=sys.stderr)
            sys.exit(1)
        print(search(files, args.query, args.top_k))


if __name__ == "__main__":
    main()
