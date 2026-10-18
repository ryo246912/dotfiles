"""HTML が相対パスで参照している画像を data URI に置き換え、1 ファイルで共有できるようにする。

http(s) や data: の参照、見つからないファイルはそのまま残す。HTML は上書きする。
"""

import argparse
import base64
import mimetypes
import re
import sys
from pathlib import Path

IMG_SRC = re.compile(r'(<img\b[^>]*?\bsrc=")([^"]+)(")')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("html", type=Path)
    args = parser.parse_args()

    base_dir = args.html.parent
    missing: list[str] = []

    def replace(match: re.Match) -> str:
        src = match.group(2)
        if re.match(r"^(https?:|data:)", src):
            return match.group(0)
        path = base_dir / src
        if not path.is_file():
            missing.append(src)
            return match.group(0)
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        data = base64.b64encode(path.read_bytes()).decode()
        return f"{match.group(1)}data:{mime};base64,{data}{match.group(3)}"

    html = IMG_SRC.sub(replace, args.html.read_text())
    args.html.write_text(html)
    for src in missing:
        print(f"見つからない画像: {src}", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
