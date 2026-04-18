---
name: overview
description: Repository overview and critical rules.
applyTo: "**"
---
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive personal dotfiles repository managed with [chezmoi](https://github.com/twpayne/chezmoi), a tool for managing configuration files across multiple machines. The repository contains configuration files for a cross-platform development environment supporting macOS and Windows/WSL2.

## Critical Rules

### ALWAYS Edit Source Files, NEVER Edit Deployed Files

- **This repository uses chezmoi to manage configuration files**
- **Source files location:** `~/.local/share/chezmoi/` (THIS repository)
- **Deployed files location:** `~/.config/`, `~/.local/`, `~/`, etc.
- **ALWAYS edit files in this repository** and then run `chezmoi apply` to deploy changes
- **NEVER edit `~/.xxx` or `~/.config/xxx` files directly** - they will be overwritten by chezmoi
- After editing source files, use `chezmoi diff` to preview changes before applying

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

## Platform Support

### macOS (darwin)

- **Karabiner Elements** - TypeScript-based key remapping
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
- **dot_config/zabrze/\*.toml** - All available command abbreviations
- **dot_config/git/config.tmpl** - Git configuration and aliases
- **.chezmoiignore** - Complete list of ignored files and patterns
