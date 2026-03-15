# DOTFILE-29 Ghostty / WezTerm Terminal Configuration

## Overview

- Add Ghostty and WezTerm configs to this chezmoi-managed repo so they can be used as tmux-first terminals alongside the existing Alacritty and Rio setup.
- Reproduce the existing terminal UX as closely as each terminal allows: HackGen Nerd font, current color palette, tmux auto-attach/new-session startup, and the tmux-oriented shortcut layer that Alacritty/Rio already provide.
- Keep the current Alacritty/Rio behavior intact while extending shared shell and tmux integration to recognize the new terminals.

## Requirements

### Functional Requirements

- Add a Ghostty config under `dot_config/ghostty/` that mirrors the current Alacritty/Rio appearance and tmux startup behavior as closely as Ghostty supports.
- Add a WezTerm config under `dot_config/wezterm/` that mirrors the current Alacritty/Rio appearance and tmux startup behavior as closely as WezTerm supports.
- Port the existing tmux-oriented shortcut layer where practical, with terminal-specific overrides for reserved/default shortcuts.
- Extend shared integration points so tmux auto-launch and terminal capability overrides work for Ghostty and WezTerm in addition to Alacritty/Rio.
- Align package-management metadata so Ghostty/WezTerm support is represented consistently in the repo.

### Non-Functional Requirements

- Preserve the current tmux-first workflow and avoid adding terminal-native behaviors that conflict with tmux.
- Keep the implementation aligned with the existing chezmoi layout and templating style used by current terminal configs.
- Limit scope to repo-managed config; do not depend on manual user edits outside this repository.

### Constraints

- Work only inside this repository copy.
- Prefer macOS-first behavior, because the current Alacritty/Rio/tmux flow and installation metadata are macOS-centric.
- Any repo-wide shared behavior change must not regress the existing Alacritty/Rio setup.

## Implementation Plan

### 1. Baseline Existing Terminal Behavior

- Extract the shared settings currently spread across `dot_config/alacritty/alacritty.toml.tmpl`, `dot_config/rio/private_config.toml.tmpl`, `dot_config/tmux/tmux.conf`, and `dot_config/zsh/dot_zshrc`.
- Normalize the parity target for:
  - font family and size
  - color palette
  - startup program / tmux attach behavior
  - macOS-oriented shortcut mappings that send tmux prefix sequences
  - TERM / terminal capability expectations
- Decide which parts should remain terminal-specific versus which should be reflected in shared tmux/zsh integration.

### 2. Add a Ghostty Config

- Create a Ghostty config in the chezmoi tree using the repo’s existing config naming conventions.
- Mirror the current tmux-first startup behavior, font, palette, and window defaults as closely as Ghostty supports.
- Recreate the existing shortcut layer where Ghostty supports sending the required text/control sequences; document any deliberate gaps if Ghostty cannot match a binding exactly.
- Ensure the Ghostty terminal identifier is accounted for in the shared tmux/zsh integration.

### 3. Add a WezTerm Config

- Create a WezTerm config in the chezmoi tree, using templating only if platform-conditional behavior is needed.
- Mirror the current tmux-first startup behavior, font, palette, and window defaults.
- Disable or override conflicting WezTerm defaults so the existing tmux-oriented shortcuts remain primary.
- Ensure the WezTerm terminal identifier and environment are accounted for in shared tmux/zsh integration.

### 4. Update Shared Integration

- Extend `dot_config/zsh/dot_zshrc` so tmux auto-attach logic recognizes the new terminal TERM values (or other reliable markers if TERM alone is insufficient).
- Extend `dot_config/tmux/tmux.conf` capability overrides so Ghostty and WezTerm receive the same true-color/passthrough behavior expected by the existing setup.
- Review any other repo-local terminal assumptions discovered during implementation, such as package metadata or terminal-specific documentation references.

### 5. Verify and Document

- Statically verify the generated configs and the diff shape.
- Use a non-GUI WezTerm command to confirm the config parses successfully in this environment.
- If Ghostty is available during implementation, validate its config load path as well; otherwise keep Ghostty validation to generated config review plus any package/config checks possible in-repo.
- Refresh repo documentation/package metadata if the supported terminal list changes.

## Files to Change

- `dot_config/ghostty/...` (new)
- `dot_config/wezterm/...` (new)
- `dot_config/tmux/tmux.conf`
- `dot_config/zsh/dot_zshrc`
- `dot_config/brew/brew_cask.json`
- `run_once_install-packages_mac.sh`
- `README.md`
- `CLAUDE.md` (only if the supported-terminal documentation should stay current)

## Verification Method

- `git diff --check`
- `wezterm --config-file "$PWD/dot_config/wezterm/wezterm.lua" show-keys >/dev/null`
- `rg -n "ghostty|wezterm|alacritty|rio" dot_config/tmux/tmux.conf dot_config/zsh/dot_zshrc README.md CLAUDE.md run_once_install-packages_mac.sh dot_config/brew/brew_cask.json`
- If `ghostty` is available during implementation: validate the generated Ghostty config with a Ghostty CLI load/show-config command against the repo-managed config path.

## Risks and Open Questions

- Ghostty and WezTerm will not support the Alacritty/Rio shortcut models identically, so some bindings may need terminal-specific compromises.
- `run_once_install-packages_mac.sh` and `dot_config/brew/brew_cask.json` already diverge today, so implementation needs to decide whether to align both or treat one as informational.
- The current branch is behind the local `origin/main` ref, so implementation must start by syncing before code edits.
- Ghostty is not installed in this environment right now, which limits runtime validation unless package setup is included as part of implementation.
