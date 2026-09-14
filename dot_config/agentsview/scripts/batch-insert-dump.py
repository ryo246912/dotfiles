#!/usr/bin/env python3
r"""dumpから、CockroachDBへ流せるINSERT列だけを取り出す。

入力は dump-inserts.sql が作るINSERTの列で、末尾に完了markerが付く。過去の
pg_dump形式（psqlのmeta-command `\restrict`、`SET`、`SELECT pg_catalog.setval(...)`
が混ざる）も読めるよう、statement単位でINSERTだけを残す。dump中のsession本文は
SQL文字列そのものを含みうるので、行のpatternではなく文字列literalとcommentを
追跡して区切る。

dumpが途中で切れていないこと、schemaを実際に読めていることは完了markerで確認する。
生成側は行が無くてもerrorにならないため、markerが唯一の手掛かりである。markerが無く、
かつ非INSERT statementを含むdumpは旧いpg_dump形式のbackupとみなして通す（その形式は
必ずSETやsetvalを含み、dump-inserts.sqlの出力はINSERTだけなので区別できる）。

出力はBEGIN/COMMITで包んだ固定件数のchunkにする。CockroachDBは1 transactionで
書ける量に上限があり、dump全体を1 transactionにすると失敗しうる。
"""

import io
import os
import re
import sys

CHUNK_ENV = "AGENTSVIEW_IMPORT_CHUNK_ROWS"
PROGRESS_ENV = "AGENTSVIEW_IMPORT_PROGRESS_ROWS"
# dump-inserts.sql が最後に置くmarker。dumpが最後まで書かれたことと、schemaを
# 実際に読めたことを示す。
MARKER = "-- agentsview-dump-complete tables="
# dollar quoteのtagは識別子と同じ規則なので、ASCII以外の文字も使える（`$é$`）。
# `[^\W\d]` は「word characterのうち数字でないもの」＝ letter か `_` で、strの
# patternでは既定でUnicodeとして解釈される。ASCIIに限ると、tagの中の `;` を
# statementの区切りと読んでdataを落とす。
TOKEN = re.compile(r"'|\"|--|/\*|;|\$[^\W\d]\w*\$|\$\$")


def chunk_size() -> int:
    """1 transactionへ入れるINSERTの件数を環境変数から読む。"""

    raw = os.environ.get(CHUNK_ENV, "500")
    try:
        value = int(raw)
    except ValueError:
        raise SystemExit(f"{CHUNK_ENV} must be a positive integer: {raw}") from None
    if value < 1:
        raise SystemExit(f"{CHUNK_ENV} must be a positive integer: {raw}")
    return value


def progress_rows() -> int:
    """進捗を出す間隔（INSERT件数）を環境変数から読む。0で無効。"""

    raw = os.environ.get(PROGRESS_ENV, "2000")
    try:
        value = int(raw)
    except ValueError:
        raise SystemExit(f"{PROGRESS_ENV} must be a non-negative integer: {raw}") from None
    if value < 0:
        raise SystemExit(f"{PROGRESS_ENV} must be a non-negative integer: {raw}")
    return value


class Splitter:
    """dumpをstatementへ切り分ける。stateは行をまたいで持続する。"""

    def __init__(self) -> None:
        """まだ何も読んでいない状態を作る。"""

        self.buffer: list[str] = []
        # bufferと同じ長さで、literal／commentの中身を空白へ置き換えたもの。SQLの句を
        # dataの中の同じ文字列と区別したいときに使う（ON CONFLICTの判定）。
        self.code: list[str] = []
        # None以外のときは、その閉じtokenまでliteral／comment内にいる。
        self.pending = ""
        self.escape = False
        self.block_depth = 0
        # bufferの末尾2文字。tokenの直前の文字を見るのに使う。statement全体を
        # 繋ぎ直すと、quoteのたびにstatementの長さだけcopyすることになる
        # （session本文のような長いrowでは、その分だけ遅くなる）。
        self.recent = ""

    def reset(self) -> None:
        """溜まっているstatementを捨てる。"""

        self.buffer = []
        self.code = []
        self.recent = ""

    def _push(self, text: str) -> None:
        """SQLとして読む部分を、bufferとcodeへそのまま足す。"""

        if not text:
            return
        self.buffer.append(text)
        self.code.append(text)
        self.recent = (self.recent + text)[-2:]

    def _hide(self, text: str) -> None:
        """literal／commentの中身として、bufferへ足しcode側は空白にする。"""

        if not text:
            return
        self.buffer.append(text)
        self.code.append(" " * len(text))
        self.recent = (self.recent + text)[-2:]

    def _context(self, line: str, index: int) -> str:
        """lineのindexの直前2文字を返す。行頭では前の行の末尾を使う。"""

        if index >= 2:
            return line[index - 2 : index]
        return (self.recent + line[:index])[-2:]

    def feed(self, line: str):
        """1行を読み、完成したstatementとそのcode部分をyieldする。"""

        pos = 0
        while pos < len(line):
            if self.pending:
                pos = self._consume_pending(line, pos)
                continue
            match = TOKEN.search(line, pos)
            if match is None:
                self._push(line[pos:])
                return
            # tokenの直前の文字を、bufferへ足す前に採る。足したあとだと、行頭側の
            # tokenでrecentとline[:index]が同じ文字を二重に数えてしまう
            # （行頭の `E'` が `EE` に見えて、backslash escapeを見落とす）。
            context = self._context(line, match.start())
            self._push(line[pos : match.start()])
            token = match.group(0)
            pos = match.end()
            if token == ";":
                self._push(";")
                statement = "".join(self.buffer)
                code = "".join(self.code)
                self.reset()
                yield statement, code
                continue
            self._push(token)
            if token == "'":
                # 直前がE（識別子の一部ではない）なら、backslash escapeが有効になる。
                # 判定に要るのは直前2文字だけなので、statement全体は繋ぎ直さない。
                self.escape = bool(re.search(r"(?:^|[^A-Za-z_0-9$])[eE]$", context))
                self.pending = "'"
            elif token == '"':
                self.escape = False
                self.pending = '"'
            elif token == "--":
                self.pending = "\n"
            elif token == "/*":
                self.block_depth = 1
                self.pending = "*/"
            else:
                # PostgreSQLは識別子の続きにある$を識別子の一部として読む。
                # pg_dumpは$を含む識別子をquoteするので実際のdumpには出ないが、
                # public.foo$bar$bazの$bar$をdollar quoteの開始にはしない。
                # $自身も識別子の続きなので含める。a$$$b$のように直前が$だと、
                # そこから先を誤ってdollar quoteとして読んでしまう。非ASCIIの
                # 文字もquoteなしの識別子に使えるので、ASCIIに限定せずisalnumで見る。
                prev = context[-1:]
                if prev and (prev.isalnum() or prev in "_$"):
                    continue
                self.escape = False
                self.pending = token

    def _consume_pending(self, line: str, pos: int) -> int:
        """literal／comment内を、閉じtokenまで読み進める。"""

        if self.pending == "\n":
            self._hide(line[pos:])
            self.pending = ""
            return len(line)
        if self.pending == "*/":
            return self._consume_block_comment(line, pos)
        closer = self.pending
        index = pos
        while True:
            if self.escape and closer == "'":
                found = self._find_quote_with_escapes(line, index)
            else:
                found = line.find(closer, index)
            if found < 0:
                self._hide(line[pos:])
                return len(line)
            end = found + len(closer)
            if closer in {"'", '"'} and line.startswith(closer * 2, found):
                # '' と "" はliteral内のescapeなので、閉じtokenではない。
                index = found + 2
                continue
            self._hide(line[pos:end])
            self.pending = ""
            self.escape = False
            return end

    def _consume_block_comment(self, line: str, pos: int) -> int:
        """入れ子を数えながらblock commentを読む。"""

        index = pos
        while self.block_depth:
            opening = line.find("/*", index)
            closing = line.find("*/", index)
            if closing < 0 and opening < 0:
                self._hide(line[pos:])
                return len(line)
            if opening >= 0 and (closing < 0 or opening < closing):
                self.block_depth += 1
                index = opening + 2
                continue
            self.block_depth -= 1
            index = closing + 2
        self._hide(line[pos:index])
        self.pending = ""
        return index

    @staticmethod
    def _find_quote_with_escapes(line: str, start: int) -> int:
        """E'...' 内で、backslash escapeを飛ばして次の ' を探す。"""

        index = start
        while index < len(line):
            char = line[index]
            if char == "\\":
                index += 2
                continue
            if char == "'":
                return index
            index += 1
        return -1

    def tail(self) -> str:
        """statementとして閉じきらずに残っている文字列を返す。"""

        return "".join(self.buffer)


def strip_leading_noise(text: str) -> str:
    """先頭のcommentと空白を落として、statement本体の先頭を返す。"""

    while True:
        text = text.lstrip()
        if text.startswith("--"):
            newline = text.find("\n")
            text = "" if newline < 0 else text[newline + 1 :]
            continue
        if text.startswith("/*"):
            # block commentは入れ子になれるので、深さを数えて閉じ位置を探す。
            # 閉じていない場合は捨てずにそのまま返す。空を返すと、fileが
            # comment途中で切れたdumpを「残りは無い」と誤って扱ってしまう。
            depth = 1
            index = 2
            while depth and index < len(text):
                opening = text.find("/*", index)
                closing = text.find("*/", index)
                if closing < 0:
                    return text
                if 0 <= opening < closing:
                    depth += 1
                    index = opening + 2
                    continue
                depth -= 1
                index = closing + 2
            if depth:
                return text
            text = text[index:]
            continue
        return text


def pending_kind(pending: str) -> str:
    """閉じ待ちのtokenを、dump本文を晒さない呼び名へ変える。"""

    if pending == "'":
        return "string literal"
    if pending == '"':
        return "quoted identifier"
    if pending == "*/":
        return "block comment"
    return "dollar-quoted string"


# COPY ... FROM stdin の検出。dataはSQLではないので取り込めない。判定はliteralを
# maskしたcode側で行うので、値の中に同じ文字列があっても誤検出しない。
COPY_FROM_STDIN = re.compile(r"COPY\b.*\bFROM\s+STDIN\b", re.IGNORECASE | re.DOTALL)

# 生成dumpのINSERTの末尾。ensure_on_conflictの早期returnに使う。句と `;` と末尾の
# 空白が収まる長さだけ遡って探す（句そのものは23文字）。
TAIL_SCAN = 64
ALREADY_ON_CONFLICT = re.compile(
    r"\bON[ \t]+CONFLICT[ \t]+DO[ \t]+NOTHING[ \t]*;[ \t\r\n]*\Z", re.IGNORECASE
)


def ensure_on_conflict(body: str, code: str) -> str | None:
    """INSERTへ ON CONFLICT DO NOTHING を補う。補えない形ならNoneを返す。

    dump-inserts.sqlの出力は既に指定済みなので変わらない。旧いplain pg_dumpの
    dumpは指定なしのINSERTを含みうるため、同じfileを再実行するとduplicate keyで
    止まる。VALUESの閉じ括弧で終わるstatementには安全に足せる。
    """

    # 生成dumpのINSERTはすべてこの形で終わる。ここで返せば、statementと同じ長さの
    # 文字列（maskしたcodeとその大文字化）を作らずに済む。下の一般の経路はstatement
    # 全体を2度大文字化して走るため、大きなrowでは目に見えて遅い（PostgreSQL 16で
    # 32MiBの値を1行流したとき1.54秒→0.30秒）。peakのmemoryは変わらない。そちらを
    # 決めているのはparserがstatementと同じ長さのmaskした並びを持つ作りである。
    #
    # 末尾のこの句は必ずSQLである。判定はbody（maskしていない側）で行うが、`;` の
    # 直前がNOTHINGのGなので、この位置がliteralの中ということはない（中なら閉じの
    # quoteがGと `;` の間に入る）。行commentとの区別のために、句と `;` の間に改行は
    # 許さない（`-- ON CONFLICT DO NOTHING` の次の行の `;` を句と読まないため）。
    # 探すのは末尾だけにする。bodyの先頭から探すと、大きなrowではstatement全体を
    # 走ることになり、避けたいはずの走査を1つ増やしてしまう。ここに収まらない形は
    # 下の一般の経路が受け持つ。
    if ALREADY_ON_CONFLICT.search(body, max(0, len(body) - TAIL_SCAN)):
        return body
    text = body.rstrip()
    if not text.endswith(";"):
        return None
    # 判定はcode側（literal／commentの中身を空白にしたもの）で行う。dataの中の
    # ON CONFLICTという文字列や、commentに書かれた句をSQLと誤認しないためである。
    # codeはbodyと同じ長さなので、同じ位置で切れる。
    code_head = code[: len(body.rstrip())].rstrip()[:-1].rstrip()
    # codeはcommentの中身を空白にするが開始tokenは残すので、`--` と `/*` も同じ長さの
    # 空白へ寄せる。これでcomment部分はすべて空白になり、位置はbodyと対応したままに
    # なる（長さの変わる大文字化は判定にだけ使い、位置には使わない）。
    masked = re.sub(r"--|/\*", "  ", code_head)
    # 既にconflict句があるstatementには足さない。`ON CONFLICT ... DO UPDATE SET x = f(y)`
    # のように括弧で終わる形もあるので、括弧の判定より先に見る。句はSQLとして正しい
    # 限り改行やcommentを挟めるため（`ON\nCONFLICT`、`ON /* c */ CONFLICT`）、
    # 単純な部分文字列では見落とす。
    if re.search(r"\bON\s+CONFLICT\b", masked.upper()):
        return body
    # RETURNINGがある形には足さない。`RETURNING (id + 1)` のように括弧で終わると、
    # 足した句がRETURNINGのあとへ入って構文errorになる（ON CONFLICTはRETURNINGより
    # 前に置く）。生成dumpには出ないが、手書きの旧形式にはありうる。
    if re.search(r"\bRETURNING\b", masked.upper()):
        return None
    # VALUESの閉じ括弧で終わるstatementにだけ足せる。`INSERT INTO t (a) SELECT ...` の
    # ように括弧が途中にあるだけの形へ足すと、別のSQLになってしまう。
    tail = masked.rstrip()
    if not tail.endswith(")"):
        return None
    # 足すのは最後の括弧の直後にする。末尾にcommentがある形（`VALUES (...) -- note`）で
    # bodyの末尾へ足すと、句と後続の `;` まで行commentの中に入ってしまう。
    pos = len(tail) - 1
    return body[: pos + 1] + " ON CONFLICT DO NOTHING" + body[pos + 1 :]


def main() -> int:
    """標準入力のdumpを読み、INSERTだけのchunkを標準出力へ書く。"""

    limit = chunk_size()
    # 大きなdumpでは取り込みに時間がかかる。件数を時々出して、止まっているのか
    # 進んでいるのか分かるようにする。
    step = progress_rows()
    splitter = Splitter()
    out = sys.stdout
    # 改行変換を明示的に切る。universal newlines（newline=None）で読むと、dataの中の
    # CRがLFへ書き換わって、復元した値が元と変わってしまう。CPythonのsys.stdinは
    # POSIXでは newline="\n" 相当で作られるため現状でも変換されないが、それは実装の
    # 細部なので、壊れると黙ってdataが変わる以上ここで固定する。
    stdin = io.TextIOWrapper(
        sys.stdin.buffer, encoding=sys.stdin.encoding, errors=sys.stdin.errors, newline="\n"
    )
    kept = 0
    skipped = 0
    # meta-commandを除いた、SQL statementとしてskipした数。旧形式の判定に使う。
    skipped_statements = 0
    in_chunk = 0
    lineno = 0
    tables = None
    # ON CONFLICT DO NOTHING を補えなかったINSERTの数。再実行が安全でない印である。
    unsafe = 0
    out.write("SET client_encoding = 'UTF8';\n")
    for lineno, line in enumerate(stdin, start=1):
        # 完了markerはstatementではないので、statementへ渡さず値だけ覚える。
        if not splitter.pending and line.startswith(MARKER):
            # markerは1つだけ。2つあるのはdumpを連結した状態で、どちらの範囲が
            # 完全なのか分からない。
            if tables is not None:
                print(
                    f"dump has more than one completion marker (after line {lineno})",
                    file=sys.stderr,
                )
                return 1
            tables = line[len(MARKER) :].strip()
            continue
        # psqlのmeta-command（`\restrict`）はSQLではないので、statement扱いしない。
        # 直前のstatementを閉じた後のcommentだけが溜まっている状態でも捨てられるよう、
        # bufferはcommentを除いて空かどうかで判定する。
        if (
            not splitter.pending
            and line.startswith("\\")
            and not strip_leading_noise(splitter.tail())
        ):
            if tables is not None:
                print(
                    f"dump has SQL after the completion marker (after line {lineno})",
                    file=sys.stderr,
                )
                return 1
            splitter.reset()
            skipped += 1
            continue

        for statement, code in splitter.feed(line):
            body = strip_leading_noise(statement)
            # bodyはstatementの末尾側なので、codeも同じ長さだけ末尾から採る。
            code_body = code[len(statement) - len(body) :]
            # markerはdumpの終端の印なので、その後にSQLがあってはならない。dumpを
            # 連結した場合、marker以降のrowまで取り込んでしまうためである。
            if body and tables is not None:
                print(
                    f"dump has SQL after the completion marker (after line {lineno})",
                    file=sys.stderr,
                )
                return 1
            if body[:6].upper() != "INSERT":
                if body:
                    # COPY ... FROM stdin のdataはSQL statementではないので、この
                    # parserからは「;で終わらない何か」にしか見えず、後続の文へ
                    # 吸われて非INSERTとして捨てられる。markerの無いdumpは旧形式
                    # として受け入れるので、そのまま0行を取り込んで成功扱いになる。
                    # 黙ってrowを失うより、読めないと言って止める。
                    if COPY_FROM_STDIN.match(strip_leading_noise(code_body)):
                        print(
                            "dump uses COPY ... FROM stdin, which this filter cannot read;"
                            " re-create it with pg_dump --column-inserts"
                            f" (after line {lineno})",
                            file=sys.stderr,
                        )
                        return 1
                    skipped += 1
                    skipped_statements += 1
                continue
            if in_chunk == 0:
                out.write("BEGIN;\n")
            fixed = ensure_on_conflict(body, code_body)
            if fixed is None:
                unsafe += 1
                fixed = body
            out.write(fixed.strip())
            out.write("\n")
            kept += 1
            in_chunk += 1
            if step and kept % step == 0:
                print(f"  {kept} INSERT statements...", file=sys.stderr, flush=True)
            if in_chunk >= limit:
                out.write("COMMIT;\n")
                in_chunk = 0
    if in_chunk:
        out.write("COMMIT;\n")
    # 文字列literal・dollar quote・block commentの途中でfileが終わっていたら、
    # 切り詰められたdumpである。取り込み済みのchunkだけで成功扱いにしないよう止める。
    # 行comment（pendingが改行）は除く。dataを持たないうえ、最後の行がちょうど
    # `--` で改行なしに終わるdumpは正常であり、閉じ待ちのまま残るためである。
    #
    # error messageにdump本文は入れない。dumpにはsession本文が入るため、terminalや
    # 収集logへ漏らさないよう、出すのはparserの状態と位置だけにする。
    if splitter.pending and splitter.pending != "\n":
        print(
            f"dump ends inside an unterminated {pending_kind(splitter.pending)}"
            f" (after line {lineno})",
            file=sys.stderr,
        )
        return 1
    leftover = strip_leading_noise(splitter.tail()).strip()
    if leftover:
        print(
            f"unterminated statement at end of dump: {len(leftover)} characters"
            f" after the last ';' (after line {lineno})",
            file=sys.stderr,
        )
        return 1
    # dumpが途中で切れていないこと、schemaを読めていることを確認する。dump生成は
    # 行が無くてもerrorにならないので、markerが唯一の手掛かりである。
    #
    # ただしmarkerが無いdumpをすべて拒むと、以前のplain pg_dump形式のbackupが
    # 取り込めなくなる。その形式は必ずSETやsetvalのような非INSERT statementを含み、
    # dump-inserts.sqlの出力はINSERTだけなので、skipしたstatementの有無で見分ける。
    # 数えるのはSQL statementだけにする。psqlのmeta-command（\restrict）はSQLでは
    # なく、それだけを根拠にすると切り詰められた新形式のdumpを旧形式と誤認しうる。
    # 再実行できない形のINSERTが残った場合は伝える。docsは「同じfileを再実行できる」
    # と書いているが、それは ON CONFLICT DO NOTHING が付いている前提である。
    if unsafe:
        print(
            f"warning: {unsafe} INSERT statements have no ON CONFLICT clause;"
            " re-running this dump can stop on duplicate keys",
            file=sys.stderr,
        )
    if tables is None and skipped_statements:
        print(
            f"INSERT statements: {kept}"
            f" (skipped {skipped} non-INSERT statements)",
            file=sys.stderr,
        )
        print(
            "note: no completion marker; read as a legacy plain pg_dump backup",
            file=sys.stderr,
        )
        return 0
    if tables is None:
        print(
            "dump is missing the completion marker; it was truncated or not produced"
            " by dump-inserts.sql",
            file=sys.stderr,
        )
        return 1
    # isdigitは全角などASCII以外の数字も真になり、tables == "0" の判定を
    # すり抜ける。markerはcount(*)の出力なので、ASCIIの10進数だけを認める。
    #
    # 読めなかった値そのものはerrorへ出さない。このfilterはdump本文をerrorへ出さない
    # （dumpにはsession本文が入るため）という約束で動いており、ここへ来る文字列は
    # 検証していない入力である。中身はdumpの最終行を見れば分かる。
    # 桁数も見る。markerはcount(*)の出力で、その値はbigintに収まる（最大19桁）。
    # 上限を置かないと、桁の多い値がそのまま下の要約へ出るうえ、intへ変換する処理を
    # 足したときにCPythonの10進変換上限（既定4300桁）でValueErrorになる。
    if re.fullmatch(r"[0-9]{1,19}", tables) is None:
        print("dump has a malformed completion marker", file=sys.stderr)
        return 1
    # 0件かどうかだけを見る。count(*)は 00 のような形を出さないが、手で書き換えた
    # markerでも0件を通さないようにする。0を落として何も残らなければ0件である。
    if not tables.lstrip("0"):
        print(
            "dump covered 0 tables; check the schema name and that the role can read it",
            file=sys.stderr,
        )
        return 1
    print(
        f"INSERT statements: {kept} from {tables} tables"
        f" (skipped {skipped} non-INSERT statements)",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    try:
        status = main()
        # 出力が小さいとbufferに残ったまま終わり、interpreterの終了時のflushで
        # pipeのerrorになる。そこは下のexceptの外なので、tracebackが出て終了statusも
        # 120になる。ここでflushして、この場合も同じ扱いにする。
        sys.stdout.flush()
        sys.exit(status)
    except BrokenPipeError:
        # 取り込み先のpsqlがerrorで先に終了すると、こちらの書き込みがpipeで切れる。
        # 原因はpsqlが出したSQLのerrorなので、ここではpipeが閉じたことだけを伝える。
        # 終了時のflushでも同じerrorが出るため、stdoutをdevnullへ差し替えてから抜ける
        # （さもないとPythonのtracebackがpsqlのerrorを埋めてしまう）。
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        print("stopped: psql closed the pipe (see its error above)", file=sys.stderr)
        sys.exit(1)
