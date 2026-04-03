import os

WIDGET_PATH = "dot_config/zsh/lazy/widget.zsh"

with open(WIDGET_PATH, "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if "_git_mux()" in line:
        if any("_git_mux()" in l for l in new_lines):
            skip = True
            continue
    if skip and line.strip() == "}":
        # Check next few lines for zle -N and bindkey
        next_lines = lines[i+1:i+10]
        if any("bindkey" in l and "_git_mux" in l for l in next_lines):
            # Find the end of this block
            j = i + 1
            while j < len(lines) and not (lines[j].strip() == "fi" or lines[j].strip() == "}"):
                j += 1
            # Skip until the end of the duplicated block
            # Actually, let us just rebuild the file to be safe.
            pass

# Rebuilding is better
