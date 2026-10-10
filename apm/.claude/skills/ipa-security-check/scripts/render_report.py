#!/usr/bin/env python3
"""
findings + verdicts を merge し、既存 Markdown レポートから triage を引き継ぎ、
新しい Markdown レポートと SARIF を書き出す。

実装する仕様:
- orchestrator.md Step 5.4 (verdict merge) / Step 6 (triage merge) / Step 7 (出力)
- output_formatter.md (3 セクション振り分け / SARIF マッピング)
- triage_state.md (既存レポートからの triage 抽出)
- templates/report.md.tmpl のプレースホルダ ({{...}}) 置換

triage parser はコードフェンス (```...```) 内の triage 風ブロックを無視するため、
テンプレ末尾のサンプルブロックを「prior triage」として誤って読み込まない。

CLI:
    python3 render_report.py <findings.json> <verdicts.json> <md_out> <sarif_out>
        [--scope-summary <str>] [--files-scanned <N>]
        [--template <path>] [--errors <path>]

findings.json は snippet_hash 付きの findings 配列を期待する
(scripts/snippet_hash.py で事前に付与しておくこと)。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_ROOT = HERE.parent
DEFAULT_TEMPLATE = SKILL_ROOT / "templates" / "report.md.tmpl"

SEV_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
VALID_STATUS = {"未対応", "対応する", "問題なし", "保留"}
SUPPRESSED_STATUS = {"問題なし", "保留"}


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def strip_fenced_blocks(text: str) -> str:
    """コードフェンス (```...```) で囲まれた領域をマスクする。
    テンプレ末尾のサンプル triage ブロックを prior_state として拾わないため。
    """
    return re.sub(r"```.*?```", "", text, flags=re.DOTALL)


def parse_triage_blocks(markdown: str) -> dict:
    """既存レポートから triage ブロックを抽出。
    triage_state.md「既存レポートの読み込み」の規定に従う。
    """
    cleaned = strip_fenced_blocks(markdown)
    pat = re.compile(
        r"<!-- ipa-triage:begin\s*\n((?:.*\n)*?)ipa-triage:end -->",
        re.MULTILINE,
    )
    result = {}
    for m in pat.finditer(cleaned):
        body = m.group(1)
        block = {}
        for line in body.split("\n"):
            line = line.strip()
            if not line or ":" not in line:
                continue
            k, _, v = line.partition(":")
            block[k.strip()] = v.strip()
        sh = block.get("snippet_hash", "")
        if not sh.startswith("sha256:"):
            continue
        status = block.get("status", "未対応")
        if status not in VALID_STATUS:
            sys.stderr.write(
                f"[triage] warn: 不正な status '{status}' → '未対応' 扱い ({sh})\n"
            )
            status = "未対応"
        result[sh] = {
            "status": status,
            "triaged_at": block.get("triaged_at", "-") or "-",
            "triaged_by": block.get("triaged_by", "-") or "-",
            "note": block.get("note", "-") or "-",
        }
    return result


def merge_verdicts(findings: list, verdicts: list) -> None:
    by_hash = {v["snippet_hash"]: v for v in verdicts}
    for f in findings:
        v = by_hash.get(f["snippet_hash"])
        f["fp_verdict"] = v["verdict"] if v else "uncertain"
        f["fp_confidence"] = v["confidence"] if v else "low"
        f["fp_reason"] = v["reason"] if v else ""


def merge_triage(findings: list, prior: dict) -> None:
    for f in findings:
        p = prior.get(f["snippet_hash"])
        if p is None:
            f["status"] = "未対応"
            f["triaged_at"] = "-"
            f["triaged_by"] = "-"
            f["note"] = "-"
        else:
            f["status"] = p["status"]
            f["triaged_at"] = p["triaged_at"]
            f["triaged_by"] = p["triaged_by"]
            f["note"] = p["note"]


def split_sections(findings: list):
    detect, fp, triaged = [], [], []
    for f in findings:
        if f["fp_verdict"] == "likely_false_positive" and f["status"] != "対応する":
            fp.append(f)
        elif f["status"] in SUPPRESSED_STATUS:
            triaged.append(f)
        else:
            detect.append(f)
    detect.sort(
        key=lambda x: (SEV_ORDER[x["severity"]], x["category"], x["file"], x["line"])
    )
    fp.sort(key=lambda x: (x["category"], x["file"], x["line"]))
    triaged.sort(key=lambda x: (x["category"], x["file"], x["line"]))
    return detect, fp, triaged


def count_by_sev(findings: list) -> dict:
    c = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
    for f in findings:
        c[f["severity"]] += 1
    return c


def render_finding_block(f: dict, extra: str = "") -> str:
    sev = f["severity"].upper()
    title_msg = f["message"].splitlines()[0]
    if len(title_msg) > 80:
        title_msg = title_msg[:80] + "…"
    ipa = f["ipa"]
    out = [
        f"#### [{sev}] {f['rule_id']} — {title_msg}",
        "",
        "<!-- ipa-triage:begin",
        f"status: {f['status']}",
        f"snippet_hash: {f['snippet_hash']}",
        f"triaged_at: {f['triaged_at']}",
        f"triaged_by: {f['triaged_by']}",
        f"note: {f['note']}",
        "ipa-triage:end -->",
        "",
        f"**Status**: {f['status']}",
        "",
        f"- **File**: `{f['file']}:{f['line']}:{f['column']}`",
        f"- **Category**: {f['category']} ({f.get('cwe', '')})",
        f"- **IPA**: [{ipa['document']} {ipa['section']} (p.{ipa['page']})]({ipa['url']})",
        f"- **Remediation Type**: {f.get('remediation_type', '-')}",
        f"- **Remediation**: {f.get('remediation', '-')}",
    ]
    if extra:
        out.append("")
        out.append(extra.rstrip())
    out += [
        "",
        "**メッセージ**:",
        "",
        f"> {f['message']}",
        "",
        "**問題箇所**:",
        "",
        "```php",
        f["code_snippet"],
        "```",
    ]
    if f.get("fix_example"):
        out += [
            "",
            "**修正例**:",
            "",
            "```php",
            f["fix_example"],
            "```",
        ]
    out.append("")
    return "\n".join(out)


def render_findings_section(findings: list, with_fp_note: bool = False) -> str:
    if not findings:
        return "_(該当なし)_"
    by_cat: dict = {}
    for f in findings:
        by_cat.setdefault(f["category"], []).append(f)
    out = []
    for cat in sorted(by_cat):
        out.append(f"### {cat}")
        out.append("")
        for f in by_cat[cat]:
            extra = ""
            if with_fp_note:
                extra = (
                    f"**FP 判定**: {f['fp_verdict']} (confidence: {f['fp_confidence']})\n"
                    f"**FP 理由**: {f['fp_reason']}"
                )
            out.append(render_finding_block(f, extra=extra))
    return "\n".join(out)


def sev_to_level(sev: str) -> str:
    return {
        "critical": "error",
        "high": "error",
        "medium": "warning",
        "low": "note",
        "info": "note",
    }[sev]


def render_sarif(findings_all: list, detect: list, fp: list, triaged: list) -> dict:
    rule_by_id: dict = {}
    for f in findings_all:
        if f["rule_id"] in rule_by_id:
            continue
        ipa = f["ipa"]
        rule_by_id[f["rule_id"]] = {
            "id": f["rule_id"],
            "name": f["rule_id"],
            "shortDescription": {"text": ipa["section"]},
            "helpUri": ipa["url"],
            "help": {
                "text": f.get("remediation", ""),
                "markdown": (
                    f"**{ipa['document']}** {ipa['section']} (p.{ipa['page']})\n\n"
                    f"{f.get('remediation', '')}"
                ),
            },
            "properties": {
                "tags": [f.get("cwe", "")],
                "category": f["category"],
            },
        }
    rules = [rule_by_id[rid] for rid in sorted(rule_by_id)]

    results = []
    for f in detect + triaged + fp:
        r = {
            "ruleId": f["rule_id"],
            "level": sev_to_level(f["severity"]),
            "message": {"text": f["message"]},
            "locations": [
                {
                    "physicalLocation": {
                        "artifactLocation": {"uri": f["file"]},
                        "region": {
                            "startLine": f["line"],
                            "startColumn": f["column"],
                            "snippet": {"text": f["code_snippet"]},
                        },
                    }
                }
            ],
            "partialFingerprints": {"snippetHash": f["snippet_hash"]},
            "properties": {
                "triageStatus": f["status"],
                "triageNote": f["note"],
                "triagedAt": f["triaged_at"],
                "triagedBy": f["triaged_by"],
                "fpVerdict": f["fp_verdict"],
                "fpReason": f["fp_reason"],
                "severity": f["severity"],
            },
        }
        if f["status"] == "問題なし":
            r["suppressions"] = [
                {
                    "kind": "external",
                    "status": "accepted",
                    "justification": f["note"] or "問題なし",
                }
            ]
        elif f["status"] == "保留":
            r["suppressions"] = [
                {
                    "kind": "external",
                    "status": "underReview",
                    "justification": f["note"] or "保留",
                }
            ]
        elif f["fp_verdict"] == "likely_false_positive":
            r["suppressions"] = [
                {
                    "kind": "external",
                    "status": "underReview",
                    "justification": f["fp_reason"] or "likely_false_positive",
                }
            ]
        results.append(r)

    return {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "IPA Security Check Skill",
                        "version": "1.0.0",
                        "informationUri": "https://www.ipa.go.jp/security/vuln/websecurity/about.html",
                        "rules": rules,
                    }
                },
                "results": results,
            }
        ],
    }


def render_markdown(template: str, ctx: dict) -> str:
    for k, v in ctx.items():
        template = template.replace(f"{{{{{k}}}}}", str(v))
    return template


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("findings", help="snippet_hash 付き findings JSON")
    parser.add_argument("verdicts", help="FP verdicts JSON")
    parser.add_argument("md_out", help="Markdown 出力先")
    parser.add_argument("sarif_out", help="SARIF 出力先")
    parser.add_argument("--scope-summary", default="(指定なし)", help="スコープ要約")
    parser.add_argument("--files-scanned", type=int, default=0, help="スキャンファイル数")
    parser.add_argument("--template", default=str(DEFAULT_TEMPLATE), help="テンプレパス")
    parser.add_argument("--errors", default="", help="errors_section 用テキスト (任意)")
    args = parser.parse_args()

    findings = json.loads(Path(args.findings).read_text(encoding="utf-8"))
    verdicts = json.loads(Path(args.verdicts).read_text(encoding="utf-8"))

    merge_verdicts(findings, verdicts)

    md_out = Path(args.md_out)
    prior: dict = {}
    if md_out.exists():
        prior = parse_triage_blocks(md_out.read_text(encoding="utf-8"))
        sys.stderr.write(
            f"[triage] 既存レポートから {len(prior)} 件のトリアージ状態を読み込み\n"
        )
    merge_triage(findings, prior)

    detect, fp, triaged = split_sections(findings)
    sev = count_by_sev(detect)

    ctx = {
        "scan_date": utcnow_iso(),
        "scope_summary": args.scope_summary,
        "files_scanned": args.files_scanned,
        "total_findings": len(detect),
        "count_critical": sev["critical"],
        "count_high": sev["high"],
        "count_medium": sev["medium"],
        "count_low": sev["low"],
        "count_info": sev["info"],
        "count_fp": len(fp),
        "count_not_an_issue": sum(1 for f in triaged if f["status"] == "問題なし"),
        "count_deferred": sum(1 for f in triaged if f["status"] == "保留"),
        "findings_by_category": render_findings_section(detect),
        "findings_false_positive": render_findings_section(fp, with_fp_note=True),
        "findings_triaged": render_findings_section(triaged),
        "errors_section": args.errors,
    }
    template_text = Path(args.template).read_text(encoding="utf-8")
    md_out.write_text(render_markdown(template_text, ctx), encoding="utf-8")

    sarif = render_sarif(findings, detect, fp, triaged)
    Path(args.sarif_out).write_text(
        json.dumps(sarif, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    sys.stderr.write(
        f"[render] detect={len(detect)} fp={len(fp)} triaged={len(triaged)}\n"
        f"[render] severity counts (detect): {sev}\n"
        f"[render] outputs: {md_out.name}, {Path(args.sarif_out).name}\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
