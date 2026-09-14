#!/usr/bin/env python3
"""batch-insert-dump のregression。`mise run test:agentsview` から実行する。

このfilterはremote dumpをlocalへ取り込む唯一の経路で、切り詰めの検出・旧形式の
受け入れ・chunk分割・comment／escape／dollar quoteの解釈を1つのparserで担う。
ここが静かに壊れると、唯一のbackupを取り込めなくなるか、statementを落として
取り込めたように見える。入力と期待をtableで持ち、filterをそのまま起動して確かめる。
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILTER = ROOT / "dot_config/agentsview/executable_batch-insert-dump"
# dump-inserts.sqlが最後に置く完了marker。既定では各caseの末尾へ足す。
MARK = "-- agentsview-dump-complete tables=1\n"


def run(text, chunk=None, marker=True):
    """filterへtextを流し、status・stdout・stderrを返す。"""

    env = dict(os.environ)
    # 呼び出したshellの設定で結果が変わらないよう、filterが読む値を固定する
    # （chunkはcaseごとに上書きする）。
    env["AGENTSVIEW_IMPORT_CHUNK_ROWS"] = "500"
    env["AGENTSVIEW_IMPORT_PROGRESS_ROWS"] = "0"
    if chunk:
        env["AGENTSVIEW_IMPORT_CHUNK_ROWS"] = str(chunk)
    body = text + (MARK if marker else "")
    proc = subprocess.run(
        [sys.executable, str(FILTER)],
        input=body,
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


cases = []


def case(name, text, *, rc=0, inserts=None, chunk=None, marker=True, contains=None, notin=None):
    """1 caseを登録する。containsはstdoutまたはstderrのどちらかに出ればよい。"""

    cases.append((name, text, rc, inserts, chunk, marker, contains, notin))

ONE = "INSERT INTO agentsview.sessions (id) VALUES ('1') ON CONFLICT DO NOTHING;\n"

case("plain insert", ONE, inserts=1)
case("legacy pg_dump artifacts",
     "SET client_encoding = 'UTF8';\n\\restrict abc\n" + ONE +
     "SELECT pg_catalog.setval('agentsview.sessions_id_seq', 7, true);\n", inserts=1)
case("semicolon inside literal",
     "INSERT INTO t (a) VALUES ('x; DROP TABLE y;') ON CONFLICT DO NOTHING;\n", inserts=1)
case("comment markers inside literal",
     "INSERT INTO t (a) VALUES ('-- not a comment /* nor this */') ON CONFLICT DO NOTHING;\n", inserts=1)
case("dollar quote spanning lines",
     "INSERT INTO t (a) VALUES ($tag$line1;\nline2$tag$) ON CONFLICT DO NOTHING;\n", inserts=1)
case("dollar sign in quoted identifier",
     'INSERT INTO t ("a$$$b$") VALUES (\'v\') ON CONFLICT DO NOTHING;\n', inserts=1)
case("dollar sign in unquoted identifier",
     "INSERT INTO t (a$$$b$) VALUES ('v') ON CONFLICT DO NOTHING;\n", inserts=1)
case("E string with escaped quote",
     "INSERT INTO t (a) VALUES (E'it\\'s; ok') ON CONFLICT DO NOTHING;\n", inserts=1)
case("E string with trailing backslash pairs",
     "INSERT INTO t (a) VALUES (E'C:\\\\path\\\\') ON CONFLICT DO NOTHING;\n", inserts=1)
case("doubled quote escape",
     "INSERT INTO t (a) VALUES ('it''s; fine') ON CONFLICT DO NOTHING;\n", inserts=1)
case("nested block comment", "/* outer /* inner */ still */\n" + ONE, inserts=1)
case("line comment before insert", "-- hello\n" + ONE, inserts=1)
case("trailing line comment without newline", ONE + MARK + "-- tail", inserts=1, marker=False)
case("multi line value",
     "INSERT INTO t (a) VALUES (E'l1\nl2\n-- c\n/* b */') ON CONFLICT DO NOTHING;\n", inserts=1)
case("two inserts one chunk", ONE + ONE, inserts=2, contains=["BEGIN;\n"], notin=["COMMIT;\nBEGIN;"])
case("chunking splits transactions", ONE * 3, inserts=3, chunk=1,
     contains=["BEGIN;\n", "COMMIT;\n"])
case("unterminated string literal", "INSERT INTO t (a) VALUES ('oops\n", rc=1,
     contains=["unterminated string literal"])
case("unterminated dollar quote", "INSERT INTO t (a) VALUES ($q$oops\n", rc=1,
     contains=["unterminated dollar-quoted string"])
case("unterminated block comment", "/* oops\n" + ONE, rc=1,
     contains=["unterminated block comment"])
case("unterminated quoted identifier", 'INSERT INTO t ("oops\n', rc=1,
     contains=["unterminated quoted identifier"])
case("statement without semicolon", "INSERT INTO t (a) VALUES ('x')\n", rc=1,
     contains=["unterminated statement"])
case("missing marker", ONE, rc=1, marker=False, contains=["missing the completion marker"])

# cubicの指摘に対するregression。
case("non-ascii identifier before dollar token",
     "INSERT INTO t (列$a$b$) VALUES ('v') ON CONFLICT DO NOTHING;\n", inserts=1)
case("non-ascii identifier with dollar quote after separator",
     "INSERT INTO t (a) VALUES ('あ', $q$x;y$q$) ON CONFLICT DO NOTHING;\n", inserts=1)
case("legacy pg_dump backup without marker",
     "SET client_encoding = 'UTF8';\n\\restrict abc\n" + ONE +
     "SELECT pg_catalog.setval('agentsview.sessions_id_seq', 7, true);\n",
     marker=False, inserts=1, contains=["legacy plain pg_dump backup"])
case("markerless dump with only inserts is rejected", ONE + ONE, rc=1, marker=False,
     contains=["missing the completion marker"])

case("markerless dump with only a meta-command is rejected",
     "\\restrict abc\n" + ONE, rc=1, marker=False,
     contains=["missing the completion marker"])
case("markerless legacy dump needs a real SQL statement",
     "SET client_encoding = 'UTF8';\n" + ONE, rc=0, marker=False,
     contains=["legacy plain pg_dump backup"])

# CodeRabbitの指摘に対するregression。
case("sql after the completion marker is rejected",
     ONE + MARK + ONE, rc=1, marker=False,
     contains=["SQL after the completion marker"])
case("meta-command after the completion marker is rejected",
     ONE + MARK + "\\restrict abc\n", rc=1, marker=False,
     contains=["SQL after the completion marker"])
case("two completion markers are rejected",
     ONE + MARK + MARK, rc=1, marker=False,
     contains=["more than one completion marker"])
case("comments after the completion marker are fine",
     ONE + MARK + "-- trailing note\n/* block */\n", inserts=1, marker=False)
case("legacy insert without on conflict is normalized",
     "SET client_encoding = 'UTF8';\nINSERT INTO t (a) VALUES ('x');\n",
     marker=False, inserts=1,
     contains=["INSERT INTO t (a) VALUES ('x') ON CONFLICT DO NOTHING;"])
case("existing conflict clause is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT (a) DO NOTHING;\n",
     marker=False, inserts=1,
     contains=["ON CONFLICT (a) DO NOTHING;"], notin=["DO NOTHING ON CONFLICT"])
case("returning clause cannot be normalized and is reported",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') RETURNING a;\n",
     marker=False, inserts=1, contains=["no ON CONFLICT clause"])
case("value ending with a paren is still normalized",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x)');\n", marker=False, inserts=1,
     contains=["VALUES ('x)') ON CONFLICT DO NOTHING;"])

case("existing do update clause ending in a paren is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT (a) DO UPDATE SET b = f(c);\n",
     marker=False, inserts=1,
     contains=["DO UPDATE SET b = f(c);"], notin=["f(c) ON CONFLICT DO NOTHING"])
case("long do update clause is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT (a) DO UPDATE"
     " SET b = 1, c = 2, d = 3, e = 4, f = 5, g = 6, h = (7);\n",
     marker=False, inserts=1, notin=["(7) ON CONFLICT DO NOTHING"])
case("data containing the phrase is still normalized",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('talk about ON CONFLICT here');\n",
     marker=False, inserts=1,
     contains=["here') ON CONFLICT DO NOTHING;"])

# 末尾が既に ON CONFLICT DO NOTHING; のstatementは、maskしたcodeを見ずに素通しする
# （ensure_on_conflictの早期return）。素通しして良い形と、してはいけない形を分ける。
case("clause with spaces before the semicolon is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT DO NOTHING  ;\n",
     marker=False, inserts=1, notin=["NOTHING ON CONFLICT DO NOTHING"])
case("lowercase clause is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') on conflict do nothing;\n",
     marker=False, inserts=1, notin=["nothing ON CONFLICT DO NOTHING"])
case("line comment spelling the clause is not the clause",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') -- ON CONFLICT DO NOTHING\n;\n",
     marker=False, inserts=1,
     contains=["VALUES ('x') ON CONFLICT DO NOTHING -- ON CONFLICT DO NOTHING"])
case("value ending with the phrase is still normalized",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('on conflict do nothing');\n",
     marker=False, inserts=1,
     contains=["nothing') ON CONFLICT DO NOTHING;"])
case("comment containing the phrase is still normalized",
     "SET x = 1;\n/* ON CONFLICT in a comment */ INSERT INTO t (a) VALUES ('x');\n",
     marker=False, inserts=1, contains=["VALUES ('x') ON CONFLICT DO NOTHING;"])
case("literal ending with a paren and the phrase",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('ON CONFLICT DO NOTHING)');\n",
     marker=False, inserts=1,
     contains=["NOTHING)') ON CONFLICT DO NOTHING;"])
case("dollar quoted value with the phrase",
     "SET x = 1;\nINSERT INTO t (a) VALUES ($q$ON CONFLICT DO NOTHING$q$);\n",
     marker=False, inserts=1, contains=["$q$) ON CONFLICT DO NOTHING;"])

case("marker with leading zeros is rejected",
     ONE + "-- agentsview-dump-complete tables=00\n", rc=1, marker=False,
     contains=["covered 0 tables"])
case("marker with a leading zero count is accepted",
     ONE + "-- agentsview-dump-complete tables=01\n", inserts=1, marker=False)
# 読めないmarkerの中身はerrorへ出さない（dump本文が混じりうるため）。"oops"は
# 下のCWE-532 guardが拾う。
case("malformed marker is rejected without echoing it",
     ONE + "-- agentsview-dump-complete tables=oops\n", rc=1, marker=False,
     contains=["malformed completion marker"])
case("non-ascii digit marker is rejected without echoing it",
     ONE + "-- agentsview-dump-complete tables=\uff10\n", rc=1, marker=False,
     contains=["malformed completion marker"], notin=["\uff10"])

# ON CONFLICT句は改行やcommentを跨げる。既存句を見落として2つ目を足さないこと。
case("existing clause across newline",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON\nCONFLICT (a) DO NOTHING;\n",
     marker=False, inserts=1,
     contains=["ON\nCONFLICT (a) DO NOTHING;"], notin=["DO NOTHING ON CONFLICT DO NOTHING"])
case("existing clause across block comment",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON /* c */ CONFLICT (a) DO NOTHING;\n",
     marker=False, inserts=1, notin=["DO NOTHING ON CONFLICT DO NOTHING"])
case("existing clause across line comment",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON -- c\nCONFLICT (a) DO NOTHING;\n",
     marker=False, inserts=1, notin=["DO NOTHING ON CONFLICT DO NOTHING"])
case("existing clause across newline ending in paren",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON\nCONFLICT (a) DO UPDATE SET b = f(c);\n",
     marker=False, inserts=1, notin=["f(c) ON CONFLICT DO NOTHING"])
case("clause words only inside literal",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('on\nconflict (a) do nothing');\n",
     marker=False, inserts=1, contains=["do nothing') ON CONFLICT DO NOTHING;"])
# commentの中に句の語があるだけなら、SQLとしては句が無い。最後の括弧の直後へ足す。
case("clause words only inside comment",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') -- on\n-- conflict do nothing\n;\n",
     marker=False, inserts=1,
     contains=["VALUES ('x') ON CONFLICT DO NOTHING -- on"], notin=["no ON CONFLICT clause"])
case("common suffix is not ON",
     "SET x = 1;\nINSERT INTO t (a) SELECT common conflict FROM u;\n",
     marker=False, inserts=1, notin=["ON CONFLICT DO NOTHING"])

# 末尾にcommentがあるINSERTでも補える。ただし句はcommentの手前へ入れる（末尾へ足すと
# 句と `;` が行commentへ入り、statementが閉じない）。
case("trailing line comment before semicolon",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') -- note\n;\n",
     marker=False, inserts=1,
     contains=["VALUES ('x') ON CONFLICT DO NOTHING -- note"], notin=["no ON CONFLICT clause"])
case("trailing block comment before semicolon",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') /* note */;\n",
     marker=False, inserts=1,
     contains=["VALUES ('x') ON CONFLICT DO NOTHING /* note */;"])
case("trailing comment with existing clause",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT DO NOTHING -- note\n;\n",
     marker=False, inserts=1, notin=["DO NOTHING ON CONFLICT DO NOTHING"])
# 括弧が途中にあるだけの形へは足さない（別のSQLになる）。
case("insert select is not touched",
     "SET x = 1;\nINSERT INTO t (a) SELECT a FROM u; -- tail\n",
     marker=False, inserts=1,
     contains=["no ON CONFLICT clause"], notin=["ON CONFLICT DO NOTHING"])
case("non-ascii identifier keeps the insert position",
     "SET x = 1;\nINSERT INTO straße (a) VALUES ('x') -- ß\n;\n",
     marker=False, inserts=1,
     contains=["VALUES ('x') ON CONFLICT DO NOTHING -- ß"])

# 値の途中で改行が入るdumpでは、次の値のquoteが行頭側へ来る。tokenの直前の文字を
# bufferへ足したあとに採ると、その1文字を二重に数えてescapeを見落とす。
case("escape string at the start of a continuation line",
     "INSERT INTO t (a, b) VALUES (\nE'it\\'s; ok', 'x') ON CONFLICT DO NOTHING;\n",
     inserts=1, contains=["E'it\\'s; ok', 'x')"])
case("lowercase escape string at the start of a continuation line",
     "INSERT INTO t (a, b) VALUES (\ne'it\\'s; ok', 'x') ON CONFLICT DO NOTHING;\n",
     inserts=1, contains=["e'it\\'s; ok', 'x')"])
case("escape string as the second character of a line",
     "INSERT INTO t (a, b) VALUES ('x',\n E'it\\'s; ok') ON CONFLICT DO NOTHING;\n",
     inserts=1, contains=["E'it\\'s; ok')"])
# 識別子の一部のEはescape stringではない（`abce` という識別子に続くliteral）。
case("identifier ending in e before a literal",
     "INSERT INTO t (a) VALUES (\nabcE'it''s; ok') ON CONFLICT DO NOTHING;\n",
     inserts=1, contains=["abcE'it''s; ok')"])
# 行頭のdollar quoteも同じ経路を通る。
case("dollar quote at the start of a continuation line",
     "INSERT INTO t (a) VALUES (\n$tag$a;b$tag$) ON CONFLICT DO NOTHING;\n",
     inserts=1, contains=["$tag$a;b$tag$)"])
case("dollar sign identifier at the start of a continuation line",
     "INSERT INTO t (\na$$$b$) VALUES ('v') ON CONFLICT DO NOTHING;\n", inserts=1)

# RETURNINGがある形には句を足さない（ON CONFLICTはRETURNINGより前に置くため）。
case("returning ending in a paren is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') RETURNING (id + 1);\n",
     marker=False, inserts=1,
     contains=["no ON CONFLICT clause"], notin=["ON CONFLICT DO NOTHING"])
case("returning a column is left alone",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') RETURNING id;\n",
     marker=False, inserts=1, notin=["ON CONFLICT DO NOTHING"])
case("returning inside a literal still gets the clause",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('RETURNING (id)');\n",
     marker=False, inserts=1, contains=["VALUES ('RETURNING (id)') ON CONFLICT DO NOTHING;"])
case("existing clause with returning is untouched",
     "SET x = 1;\nINSERT INTO t (a) VALUES ('x') ON CONFLICT DO NOTHING RETURNING id;\n",
     marker=False, inserts=1, notin=["DO NOTHING RETURNING id ON CONFLICT"])

fails = 0
for name, text, rc, inserts, chunk, marker, contains, notin in cases:
    got_rc, out, err = run(text, chunk=chunk, marker=marker)
    problems = []
    if got_rc != rc:
        problems.append(f"rc {got_rc} != {rc} ({err.strip()})")
    if inserts is not None:
        n = sum(1 for line in out.splitlines() if line.upper().startswith("INSERT"))
        if n != inserts:
            problems.append(f"inserts {n} != {inserts}")
    for needle in contains or []:
        if needle not in out and needle not in err:
            problems.append(f"missing {needle!r}")
    # containsと同じく両方のstreamを見る。出力先が変わっても、出てはいけない形が
    # 素通りしないようにする。
    for needle in notin or []:
        if needle in out or needle in err:
            problems.append(f"unexpected {needle!r}")
    # dump本文をerrorへ出していないこと（CWE-532）。
    if got_rc != 0 and any(tok in err for tok in ("oops", "INSERT INTO")):
        problems.append("stderr leaks dump text")
    if problems:
        fails += 1
        print(f"FAIL {name}: {'; '.join(problems)}")
print(f"{len(cases) - fails}/{len(cases)} passed")
sys.exit(1 if fails else 0)
