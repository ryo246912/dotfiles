# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive personal dotfiles repository managed with [chezmoi](https://github.com/twpayne/chezmoi), a tool for managing configuration files across multiple machines. The repository contains configuration files for a cross-platform development environment supporting macOS and Windows/WSL2.

**Repository Statistics:**
- Total files: 5,990+
- Total size: ~53MB
- Managed tools: 46 applications
- Tool definitions (mise): 100+
- Command abbreviations: 200+
- Zsh plugins: 30+

## Critical Rules

### ALWAYS Edit Source Files, NEVER Edit Deployed Files

- **This repository uses chezmoi to manage configuration files**
- **Source files location:** `~/.local/share/chezmoi/` (THIS repository)
- **Deployed files location:** `~/.config/`, `~/.local/`, `~/`, etc.
- **ALWAYS edit files in this repository** and then run `chezmoi apply` to deploy changes
- **NEVER edit `~/.xxx` or `~/.config/xxx` files directly** - they will be overwritten by chezmoi
- After editing source files, use `chezmoi diff` to preview changes before applying

## Repository Structure

```
~/.local/share/chezmoi/
├── dot_config/              # XDG config directory (46 tool configurations)
│   ├── zsh/                # Zsh shell configuration
│   ├── nvim/               # NeoVim editor configuration
│   ├── alacritty/          # Alacritty terminal configuration
│   ├── tmux/               # tmux multiplexer configuration
│   ├── git/                # Git configuration with Delta
│   ├── mise/               # mise tool version manager
│   ├── karabiner-ts/       # Karabiner Elements (macOS)
│   ├── autohotkey/         # AutoHotkey (Windows)
│   ├── claude/             # Claude Desktop configuration
│   ├── devcontainer/       # Dev Container configuration
│   ├── zabrze/             # Shell abbreviations system
│   └── [40+ other tools]   # See "Configuration Files" section
├── dot_claude/             # Claude AI tool settings and commands
├── dot_gemini/             # Google Gemini API settings and commands
├── dot_local/bin/          # Custom utility scripts (8 scripts)
├── not_config/             # Non-chezmoi managed files (snippets, memos)
├── run_once_*.sh          # One-time setup scripts
├── run_onchange_*.sh.tmpl # Scripts run when dependencies change
├── mise.toml              # Root-level mise configuration
├── setup.md               # Detailed setup instructions
├── README.md              # Repository description
├── CLAUDE.md              # This file
├── .chezmoiignore         # Platform-specific ignore patterns
└── .github/               # GitHub Actions workflows
    └── workflows/         # lint.yaml, renovate.json
```

## Tool Management System

This repository uses a hierarchical tool management system:

```
mise (Main tool version manager)
├── aqua (YAML-based package manager)
│   └── 50+ Go/Rust/Other tools
├── npm (Node.js package manager)
│   └── 20+ tools & CLIs
├── cargo (Rust package manager)
│   └── Rust tools (fzf-make, etc.)
├── pipx (Python isolated environments)
│   └── Python tools (zizmor, etc.)
├── go (Go language packages)
│   └── Go CLI tools
└── ubi (Universal binary installer)
    └── Latest Rust/Go tools

Homebrew (macOS only)
├── Regular packages (git, go, gpg, sqlite3, etc.)
└── Cask (GUI applications)

Scoop (Windows/WSL2)
└── Windows-specific apps & CLIs
```

## Key Commands

### Chezmoi Management

- `chezmoi apply` - Apply changes from source to destination
- `chezmoi apply --interactive` - Interactive apply with confirmation
- `chezmoi edit --interactive --apply` - Edit and apply configuration files
- `chezmoi diff` - Show differences between source and destination
- `chezmoi list -p source-absolute -i files` - List all managed files
- `chezmoi cd` - Change to chezmoi source directory
- `chezmoi add <file>` - Add new file to chezmoi management

### Development Tools

**Package Management:**
- `mise install` - Install all tools defined in mise.toml
- `mise use <tool>@<version>` - Use specific tool version
- `mise run <task>` - Run defined tasks (lint, format, etc.)

**Terminal:**
- Alacritty with tmux as terminal multiplexer
- Rio terminal as alternative
- Auto-launch tmux in Alacritty/Rio terminals

**Shell:**
- zsh with zinit plugin manager (30+ plugins)
- Lazy loading for fast startup
- XDG Base Directory Specification compliance

**Editor:**
- NeoVim with lazy.nvim plugin manager (Lua-based)
- VSCode with custom settings, keybindings, and snippets
- Vim with basic configuration

**Git UI:**
- gitui - Terminal UI for Git
- lazygit - Another Git terminal UI
- tig - Text-mode interface for Git
- gh-dash - GitHub Dashboard CLI

**AI Integration:**
- Claude Desktop with custom commands (kiro, deepwiki, article, review-fix)
- Gemini API integration

### Abbreviations System

The repository uses [zabrze](https://github.com/orhun/zabrze) for shell abbreviations. Configuration is split into multiple TOML files:

**Git abbreviations (80+ aliases in `git.toml`):**
- `ga` → `git add`
- `gc` → `git commit`
- `gd` → `git diff`
- `gp` → `git push`
- `gl` → `git log`
- `gs` → `git status`
- `gwta` → `git worktree add`
- `gwtl` → `git worktree list`
- And many more...

**Chezmoi abbreviations (`chezmoi.toml`):**
- `che` → `chezmoi edit`
- `chad` → `chezmoi add`
- `chap` → `chezmoi apply`
- `chd` → `chezmoi diff`
- `chl` → `chezmoi list`

**GitHub CLI abbreviations (`gh.toml`):**
- `ghpl` → `gh pr list`
- `ghpv` → `gh pr view`
- `ghpc` → `gh pr create`
- `ghil` → `gh issue list`

**Docker abbreviations (`docker.toml`):**
- `dco` → `docker compose`
- `dps` → `docker ps`
- `dim` → `docker images`

**npm abbreviations (`npm.toml`):**
- `nrd` → `npm run dev`
- `nrl` → `npm run lint`
- `nrt` → `npm run test`
- `nrb` → `npm run build`

**mise abbreviations (`mise.toml`):**
- `mii` → `mise install`
- `miu` → `mise use`
- `mir` → `mise run`

**General abbreviations (`general.toml`):**
- Various system commands and shortcuts

**Platform-specific (`mac.toml`):**
- macOS-specific commands

## Configuration Files

This repository manages 46+ tool configurations in `dot_config/`:

### Terminal & Shell (7 tools)
- `alacritty/` - Alacritty terminal emulator (TOML config with keybindings)
- `rio/` - Rio terminal emulator
- `tmux/` - tmux terminal multiplexer (custom keybindings, status bar)
- `tig/` - Tig Git TUI
- `zsh/` - Zsh shell (modularized with lazy loading)
- `zabrze/` - Command abbreviations (10 TOML files, 200+ abbreviations)
- `atuin/` - Shell history manager (fuzzy search, sync support)

### Editors & IDEs (4 tools)
- `nvim/` - NeoVim (Lua-based, lazy.nvim, 20+ plugins)
  - `lua/core/` - Options, keymaps, autocmds, config
  - `lua/plugins/` - Colorscheme, Copilot, editor, Git, filer, etc.
- `vscode/` - VSCode (settings, keybindings, snippets, projects)
- `vim/` - Vim basic configuration
- `karabiner-ts/` - Karabiner Elements (TypeScript-based keymap, macOS only)

### Git Related (3 tools)
- `git/` - Git configuration (Delta diff tool, GPG signing, platform-specific)
- `gitui/` - gitui TUI (custom commands: czg, chezmoi, nvim, gh-dash)
- `lazygit/` - lazygit TUI

### Development Tools (5 tools)
- `mise/` - Tool version manager (100+ tools, task definitions, conf.d/ splits)
- `aqua/` - YAML-based package manager
- `nix/` - Nix package manager
- `gotip/` - Go development configuration
- `commitizen/` - Commitizen (Japanese-compatible commit message linting)

### AI & Development Support (5 tools)
- `claude/` - Claude Desktop (macOS/Windows configs, MCP servers)
- `devcontainer/` - Dev Container configuration
- `deck/` - Deck tool
- `koji/` - Koji tool
- `ccmanager/` - ccmanager development tool

### Search & Navigation (5 tools)
- `fzf/` - fzf fuzzy finder (lazy loaded from zsh)
- `yazi/` - yazi file manager
- `navi/` - navi interactive cheatsheet
- `gh-dash/` - GitHub Dashboard CLI
- `lnav/` - Log file navigator

### Container & Cloud (3 tools)
- `lazydocker/` - Docker TUI
- `dive/` - Docker image analyzer
- `rclone/` - Cloud storage sync

### Platform-Specific (4 tools)
- `karabiner-ts/` - Karabiner Elements (macOS key remapping, TypeScript)
- `autohotkey/` - AutoHotkey (Windows key remapping)
- `scoop/` - Scoop package manager (Windows/WSL2)
- `raycast/` - Raycast launcher (macOS)

### Other Tools (10+ tools)
- `brew/` - Homebrew (macOS package lists)
- `obsidian/` - Obsidian note-taking app
- `dbeaver/` - DBeaver database tool
- `vimium/` - Vimium browser extension
- `sidebery/` - Sidebery tab manager
- `tbkeys/` - Thunderbird keybindings
- `chezmoi/` - chezmoi itself (delta pager, VSCode editor)
- `act/` - GitHub Actions local runner
- `ghtkn/` - GitHub token manager
- `silicon/` - Code screenshot tool
- `laminate/` - Log formatter

## Template System

Chezmoi templates (6 files with `.tmpl` extension) enable platform-specific configurations:

**Template Features:**
- OS detection: `{{ if eq .chezmoi.os "darwin" }}` for macOS/Windows/Linux
- Command execution: `{{ output "brew" "shellenv" }}` for shell command output
- File inclusion: `{{ include "path/to/file" }}` for other file references
- Hash calculation: `{{ sha256sum }}` for change detection

**Template Files:**
1. `dot_config/zsh/dot_zshenv.tmpl` - Zsh environment variables (XDG, PATH)
2. `dot_config/git/config.tmpl` - Git config (platform-specific, Delta integration)
3. `dot_config/alacritty/alacritty.toml.tmpl` - Alacritty terminal config
4. `dot_config/rio/private_config.toml.tmpl` - Rio terminal config
5. `dot_config/zsh/lazy/work.zsh.tmpl` - Work-specific zsh config
6. `dot_config/dot_czrc.tmpl` - commitizen configuration

## Platform Support

### macOS (darwin)
- **Karabiner Elements** - TypeScript-based key remapping
  - generalRule, applicationRule, japaneseKanaRule, spacebarRule
- **Raycast** - Launcher and productivity tool
- **Homebrew** - Package manager (brew.json, brew_cask.json)
- **macOS system settings** - Automated via `run_once_install-packages_mac.sh`
  - Menu bar spacing, hidden files, keyboard speed, login items
- **pinentry-mac** - GPG passphrase input
- **zsh-auto-notify** - Command completion notifications

### Windows/WSL2 (linux)
- **Scoop** - Package manager for Windows
- **AutoHotkey** - Key remapping for Windows
- **PowerShell** - Integration and compatibility

### Cross-Platform (Both)
- Git configuration with Delta
- VSCode settings (platform-specific keybindings)
- Zsh configuration (core parts)
- mise tool management
- Docker integration
- GitHub CLI integration
- All terminal tools (Alacritty, tmux, etc.)

## Scripts and Automation

### Setup Scripts (run_once_*.sh)

These scripts run only once during initial setup:

1. **run_once_install-packages_mac.sh** - macOS initial setup
   - Homebrew installation
   - Regular packages: git, go, gpg, mise, bun, etc.
   - Cask apps: Alacritty, Arc, Docker, VSCode, Raycast, etc.
   - Private apps: Bitwarden, Claude, Obsidian, Thunderbird, etc.
   - Work apps: Inkscape, Jira CLI
   - macOS system settings automation
   - Login item configuration (Clibor, Docker, Raycast)
   - Nix package manager support

2. **run_once_install-packages_windows.sh** - Windows/WSL2 setup
   - Scoop package manager installation
   - APT packages: git, gpg, zsh, ugrep
   - Scoop apps: Alacritty, Firefox, Obsidian, VSCode
   - Private apps: NeeView

3. **run_once_setup.sh** - Basic initial setup
   - ZDOTDIR configuration
   - Symlink creation for ~/.zshenv

### Change-Triggered Scripts (run_onchange_*.sh.tmpl)

These scripts run when their content or dependencies change:

1. **run_onchange_copy.sh.tmpl** - File copying with hash tracking
   - commitizen config file copying (commitlintrc.js)
   - Conditional copying (command existence check)

2. **run_onchange_mac.sh.tmpl** - macOS-specific file copying
   - Claude Desktop config
   - VSCode settings (keybindings, settings, snippets)
   - Navi config files

3. **run_onchange_windows.sh.tmpl** - Windows-specific file copying
   - Claude Desktop config
   - AutoHotkey settings
   - Alacritty/Rio configs
   - VSCode settings (multiple path support)

## AI Integration

### Claude Desktop

**Configuration Files:**
- `dot_config/claude/claude_desktop_config_mac.json` - macOS config
- `dot_config/claude/claude_desktop_config_win.json` - Windows config

**Custom Commands (Skills):**
- `kiro` - Spec-driven development
- `deepwiki` - GitHub Wiki search using deepwiki tool
- `article` - Technical article creation
- `review-fix` / `pr-review` - PR review comment handling and code fixes

### Gemini API

**Location:** `dot_gemini/`
- Gemini-specific configuration and custom commands

## Custom Scripts

Location: `dot_local/bin/` (8 utility scripts)

1. **setup-git-gpg** - Automated Git & GPG signing setup
   - Configures Git user information
   - Sets up GPG key for commit signing
   - Enables automatic signing

2. **setup-github** - GitHub repository automation
   - Repository ruleset configuration
   - Dependabot setup
   - Branch protection rules

3. **setup-ai-tool** - AI tool initialization
   - Claude/Gemini configuration
   - API key setup

4. **claude-heartbeat** - Claude CLI heartbeat monitoring
   - Monitors Claude CLI status
   - Automatic restart on failure

5. **deepwiki** - GitHub Wiki search
   - Search GitHub Wiki content
   - Integration with MCP server

6. **git-worktree-manager** - Git worktree management
   - Create, list, remove worktrees
   - Simplified worktree workflow

7. **bluetooth** - Bluetooth device management (macOS only)
   - Connect/disconnect Bluetooth devices
   - Device listing

8. **capture** - Screenshot & video capture
   - Screen capture automation
   - Video recording

9. **graphql-format** - GraphQL formatter
   - Format GraphQL queries and schemas

## Git Workflow

### GPG Signing (Automatic)

All commits are automatically GPG-signed:
```bash
git config user.signingkey 08BF9A27112516E5
commit.gpgsign = true
```

### Git Worktree Structure

**Active Worktrees:**
```
/Users/ryo./.local/share/chezmoi/.git/worktrees/
├── playground/      # Testing and experimentation
├── test-commit/     # Commit testing

/Users/ryo/.local/share/worktrees/
├── chore/dein-to-lazyvim/  # Migration work
└── feat/quotio/            # Feature development
```

### Delta Integration

Git uses [Delta](https://github.com/dandavison/delta) as the diff pager for enhanced diff viewing with syntax highlighting.

## Zsh Configuration

### Plugin System (zinit)

**Key Features:**
- **Lazy loading** with `wait` modifier for fast startup
- **30+ plugins** managed by zinit
- **Modular configuration** in `dot_config/zsh/lazy/`

**Important Plugins:**
- `fzf` - Fuzzy finder integration
- `zsh-autosuggestions` - Command auto-completion
- `zsh-autopair` - Auto-pairing brackets
- `fast-syntax-highlighting` - Syntax highlighting
- `zsh-auto-notify` - Long command notifications (macOS)
- Git, Docker, docker-compose completions

### Modular Structure

Configuration split into multiple files in `lazy/`:
- `plugin.zsh` - zinit plugin definitions (30+ plugins)
- `alias.zsh` - Command aliases
- `bindkey.zsh` - Keybindings
- `function.zsh` - Custom functions
- `fzf-function.zsh` - fzf integration functions
- `mac.zsh` / `wsl.zsh` - Platform-specific settings
- `main.zsh` - General configuration
- `mise.zsh` - mise tool integration
- `terminal.zsh` - Terminal-related settings
- `widget.zsh` - Zsh widget configuration
- `work.zsh.tmpl` - Work-specific settings (template)

### XDG Base Directory Compliance

```bash
XDG_CONFIG_HOME=~/.config
XDG_CACHE_HOME=~/.cache
XDG_DATA_HOME=~/.local/share
XDG_STATE_HOME=~/.local/state
ZDOTDIR=~/.config/zsh
```

All history, cache, and state files are separated into dedicated directories following the XDG specification.

## Chezmoi Special Files

### .chezmoiignore

Platform-specific and sensitive file exclusions:

**OS-specific exclusions:**
- `**/*autohotkey*` (ignored on macOS)
- `**/*karabiner*` (ignored on Windows/Linux)
- `**/*raycast*` (ignored on Windows/Linux)
- `**/*brew*` (ignored on Windows/Linux)
- `**/*mac*` (ignored on Windows/Linux)
- `**/*win*` (ignored on macOS)

**Application-specific exclusions:**
- `.config/claude*`
- `.config/dbeaver*`
- `.config/memo*`
- `.config/rclone*`
- `.config/sidebery*`
- `.config/vscode*`

**Non-managed directories:**
- `not_config*`
- `_*`

### chezmoi.toml

Chezmoi configuration:
```toml
pager = "delta"

[edit]
command = "code"
args = ["--wait", "--new-window"]

[scriptEnv]
APPDATA = "/mnt/c/Users/r-ksk/AppData"
USERDIR = "/mnt/c/Users/r-ksk"

[bitwarden]
unlock = "auto"
```

## Setup Workflow

### Initial Setup Process

1. **Clone and initialize repository:**
   ```bash
   chezmoi init --apply ryo246912
   ```

2. **Install system packages:**
   - macOS: `run_once_install-packages_mac.sh` runs automatically
   - Windows/WSL2: `run_once_install-packages_windows.sh` runs automatically

3. **Basic setup:**
   - `run_once_setup.sh` configures ZDOTDIR and symlinks

4. **Install development tools:**
   ```bash
   mise install
   ```

5. **Configure Git and GPG:**
   ```bash
   setup-git-gpg
   ```

6. **Configure GitHub repositories:**
   ```bash
   setup-github
   ```

7. **Apply Karabiner key mappings (macOS only):**
   ```bash
   mise run karabiner-apply
   ```

### Daily Workflow

1. **Make configuration changes:**
   - Edit files in `/Users/ryo./.local/share/chezmoi/`
   - Use `chezmoi edit` for convenience

2. **Preview changes:**
   ```bash
   chezmoi diff
   ```

3. **Apply changes:**
   ```bash
   chezmoi apply
   # or interactively
   chezmoi apply --interactive
   ```

4. **Commit changes:**
   ```bash
   git add .
   git commit -m "feat: description"  # Auto-signed with GPG
   git push
   ```

## GitHub Actions

### Workflows (`.github/workflows/`)

1. **lint.yaml** - Multi-format linting
   - TOML files (taplo)
   - JSON files (prettier)
   - YAML files (prettier, actionlint)
   - GitHub Actions workflow syntax

2. **lint-action.yaml** - GitHub Actions-specific linting
   - Validates workflow syntax and best practices

### Automation

- **renovate.json** - Automated dependency updates
  - Monitors tool versions
  - Creates PRs for updates

- **copilot-instructions.md** - AI interaction logging
  - Conversation history tracking preferences

## Important Development Patterns

### 1. Infrastructure as Code Philosophy

This repository treats personal development environment as code:
- All configurations versioned in Git
- Reproducible across machines
- Platform-independent where possible
- Automated setup and deployment

### 2. Modularization

- Zsh configuration split into `lazy/` modules
- mise configuration split into `conf.d/` files
- Zabrze abbreviations split by category
- Chezmoi scripts split by purpose

### 3. Lazy Loading

- Zsh plugins loaded lazily with zinit `wait` modifier
- Reduces shell startup time significantly
- Only loads what's needed when needed

### 4. Cross-Platform Design

- Templates handle platform differences
- Shared core with platform-specific extensions
- Conditional loading based on OS detection

### 5. Security Best Practices

- GPG signing for all commits
- Sensitive files excluded via .chezmoiignore
- Private configurations separated from public
- API keys and credentials never committed

## Important Notes

- **CRITICAL: Always edit source files in this repository, never edit deployed files directly**
  - This repository uses chezmoi to manage configuration files
  - The source files are located in `/Users/ryo./.local/share/chezmoi/` (this repository)
  - Deployed files are located in `~/.config/`, `~/.local/`, etc.
  - **Always edit files in this repository** and then run `chezmoi apply` to deploy changes
  - **Never edit `~/.xxx` or `~/.config/xxx` files directly** as they will be overwritten by chezmoi
  - After editing source files, use `chezmoi diff` to preview changes before applying

- **Git worktree workflow is mandatory for feature/fix development**
  - Always create dedicated worktrees for new work
  - Verify code works correctly before committing
  - Ensure no errors exist before committing

- This repository contains personal configurations; be careful with sensitive data

- The `.github/copilot-instructions.md` contains AI interaction logging preferences

- Many configurations are cross-platform with conditional logic for OS-specific behavior

- The abbreviation system is extensive - check `dot_config/zabrze/*.toml` for all command shortcuts
- XDG Base Directory specification is fully implemented - all configs follow XDG standards

- The repository supports both personal and work environments with dedicated configuration files

- All command-line tools are managed through mise for version consistency

- Chezmoi templates use hash-based change detection for efficient updates

## Useful References

- **setup.md** - Detailed step-by-step setup instructions
- **README.md** - Repository overview and quick start
- **mise.toml** - Complete list of managed tools and available tasks
- **dot_config/zabrze/*.toml** - All available command abbreviations
- **dot_config/git/config.tmpl** - Git configuration and aliases
- **.chezmoiignore** - Complete list of ignored files and patterns
