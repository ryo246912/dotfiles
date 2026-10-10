#!/usr/bin/env python3
"""config/mise/config.toml の "~/.config" track entry の include が、
このリポジトリが ~/.config へ配置するもの（config/・config-mac/・config-linux/ の
トップレベル要素と、mise*.toml の [dotfiles] にある "~/.config/<name>/..." target）と
一致しているかを検査する。

include に無いものは history に一切記録されないため、config/ に新しいディレクトリを
足したら include への追加漏れをここで検出する。逆に、配置しなくなったものが include に
残っている場合も検出する（~/.config にしか無い同名ディレクトリを巻き込まないため）。
"""

import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GLOBAL_CONFIG = ROOT / "config/mise/config.toml"
SOURCE_DIRS = ["config", "config-mac", "config-linux"]
PROJECT_CONFIGS = ["mise.toml", "mise.mac.toml", "mise.linux.toml"]
TARGET_PREFIX = "~/.config/"


def pattern_for(name: str, is_dir: bool) -> str:
    return f"{name}/**" if is_dir else f"/{name}"


def expected_patterns() -> set[str]:
    patterns = set()
    for source in SOURCE_DIRS:
        for entry in (ROOT / source).iterdir():
            patterns.add(pattern_for(entry.name, entry.is_dir()))
    for config in PROJECT_CONFIGS:
        dotfiles = tomllib.loads((ROOT / config).read_text()).get("dotfiles", {})
        for target in dotfiles:
            rest = target.removeprefix(TARGET_PREFIX)
            if rest != target and "/" in rest:
                patterns.add(pattern_for(rest.split("/", 1)[0], True))
    return patterns


def main() -> int:
    dotfiles = tomllib.loads(GLOBAL_CONFIG.read_text()).get("dotfiles", {})
    actual = set(dotfiles.get("~/.config", {}).get("include", []))
    expected = expected_patterns()

    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if not missing and not extra:
        return 0

    rel = GLOBAL_CONFIG.relative_to(ROOT)
    print(f'error: {rel} の "~/.config" include が配置対象と一致しません', file=sys.stderr)
    for pattern in missing:
        print(f'  missing: "{pattern}"', file=sys.stderr)
    for pattern in extra:
        print(f'  extra:   "{pattern}"', file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
