#!/usr/bin/env python3
"""標準入力をfileへbyteのまま書きながら、進捗をstderrへ出す。

psqlはdumpを書き出している間なにも言わない。remote（CockroachDB Cloud）のように
時間のかかる相手では、止まっているのか進んでいるのか分からなくなる。報告は別threadで
時間ごとに出すので、serverが最初の行を返すまで待っている間も「まだ0行」と分かる。

使い方:
  <psqlの出力> | dump-progress <出力file>

間隔は AGENTSVIEW_DUMP_PROGRESS_SECONDS（既定15秒、0で無効）で変えられる。
"""

import os
import sys
import threading
import time
from decimal import Decimal, InvalidOperation

INTERVAL_ENV = "AGENTSVIEW_DUMP_PROGRESS_SECONDS"
# 報告間隔の下限。これより短くしても、報告が並ぶだけで進捗は読めない。
MIN_INTERVAL = 0.1
# 1度に読むbyte数。行の長さに関係なく、この量しかmemoryへ載せない。
CHUNK_BYTES = 1 << 20


def interval() -> float:
    """進捗を出す間隔を環境変数から読む。"""

    raw = os.environ.get(INTERVAL_ENV, "15")
    limit = threading.TIMEOUT_MAX
    bad = (
        f"{INTERVAL_ENV} must be 0 (disables it) or between {MIN_INTERVAL}"
        f" and {limit:.0f} seconds: {raw}"
    )
    # 検査はDecimalで行う。floatにすると 1e-400 のような値が 0.0 へ丸められ、
    # 「0＝無効」と区別できなくなる（黙って進捗が出なくなる）。
    try:
        value = Decimal(raw)
    except InvalidOperation:
        raise SystemExit(bad) from None
    # nanとinfは範囲比較の前に落とす（Decimalのnanは順序比較でerrorになる）。
    # Event.waitへ渡すと、nanは即座に返って報告のloopが空回りしstderrを埋め、
    # TIMEOUT_MAXを超える値はOverflowErrorになる。1e-300のようなtimerの分解能より
    # 小さい正の値も待たずに返るので同じ空回りになる。どれも報告threadが起きる前に
    # ここで止める。
    if not value.is_finite():
        raise SystemExit(bad)
    if value != 0 and not Decimal(str(MIN_INTERVAL)) <= value <= Decimal(limit):
        raise SystemExit(bad)
    return float(value)


class Counter:
    """書き出した行数とbyte数。報告threadと共有する。"""

    def __init__(self) -> None:
        """まだ何も書いていない状態を作る。"""

        self.lines = 0
        self.written = 0
        self.started = time.monotonic()

    def report(self, note: str = "") -> None:
        """今の値を1行でstderrへ出す。"""

        elapsed = time.monotonic() - self.started
        print(
            f"  {elapsed:.0f}s: {self.lines} lines, {self.written / 1048576:.1f} MiB{note}",
            file=sys.stderr,
            flush=True,
        )


def ticker(counter: Counter, every: float, done: threading.Event) -> None:
    """終わるまで、一定時間ごとに進捗を出す。"""

    while not done.wait(every):
        counter.report()


def main() -> int:
    """標準入力をfileへ写しながら、進捗を報告する。"""

    if len(sys.argv) != 2:
        print("usage: dump-progress <file>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    every = interval()
    counter = Counter()
    done = threading.Event()
    if every:
        threading.Thread(target=ticker, args=(counter, every, done), daemon=True).start()
    # byteのまま写す。dumpにはsession本文が入るので、hostのlocaleでdecode／encodeし
    # 直すと非ASCIIが壊れうる。
    #
    # 行ではなく固定長で読む。dumpは1 rowが1行なので、session本文の大きなrowでは
    # 1行がそのままmemoryへ載る。ここで使う量をchunk sizeで抑える（行数は読んだ
    # byte列の改行を数える）。
    # dumpにはsession本文が入るので、書く前にこのfileのmodeを0600へ落とす。呼び出し元も
    # そうしているが、既にあるfileへ書く場合はそのfileのmodeが残るため、書く側でも
    # 確かめる（file名を知っている他userに、書いている最中の中身を読ませない）。
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with open(fd, "wb") as out:
        while True:
            chunk = sys.stdin.buffer.read(CHUNK_BYTES)
            if not chunk:
                break
            out.write(chunk)
            counter.lines += chunk.count(b"\n")
            counter.written += len(chunk)
    done.set()
    # 進捗を無効にしている場合（間隔0）は、完了の1行も出さない。
    if every:
        counter.report(" (done)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
