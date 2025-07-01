# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://github.com/twpayne/chezmoi), a tool for managing configuration files across multiple machines. The repository contains configuration files for a cross-platform development environment supporting MacOS and Windows/WSL2.

## Key Commands

### Chezmoi Management
- `chezmoi apply`: Apply changes from source to destination
- `chezmoi apply --interactive`: Interactive apply with confirmation
- `chezmoi edit --interactive --apply`: Edit and apply configuration files
- `chezmoi diff`: Show differences between source and destination
- `chezmoi list -p source-absolute -i files`: List all managed files

### Development Tools
- **Package Management**: `mise` for tool version management
- **Terminal**: Alacritty with tmux as terminal multiplexer
- **Shell**: zsh with zinit plugin manager
- **Editor**: VSCode and NeoVim
- **Git UI**: gitui, tig for terminal git interfaces

### Abbreviations System
The repository uses [zabrze](https://github.com/orhun/zabrze) for shell abbreviations. Key abbreviations include:
- `ch*`: chezmoi commands (che, chad, chap, etc.)
- `g*`: git commands (ga, gc, gd, etc.)
- `gh*`: GitHub CLI commands (ghpl, ghpv, etc.)
- `nr*`: npm run commands (nrd, nrl, nrt, etc.)

## Architecture

### Configuration Structure
- `dot_config/`: XDG config directory files (prefixed with `dot_` for chezmoi)
- `run_*`: Scripts executed by chezmoi during apply operations
- `not_config/`: Files not managed by chezmoi (snippets, memos, shortcuts)
- `_ai/`: AI-related files including chat logs and todos

### Template System
Some files use chezmoi's templating system (`.tmpl` extension) for platform-specific configurations:
- OS detection: `{{ if eq .chezmoi.os "darwin" }}`
- Environment variables in `.gitconfig.tmpl`

### Platform Support
- **MacOS**: Native support with Karabiner for key mapping
- **Windows/WSL2**: WSL-specific configurations and Windows utilities

## File Patterns

### Ignored Files (.chezmoiignore)
- Platform-specific exclusions (AutoHotkey on Mac, Karabiner on Windows)
- Private configurations (Claude, DBeaver, VSCode settings)
- Temporary files and build artifacts

### Script Execution
- `run_once_*`: One-time setup scripts
- `run_onchange_*`: Scripts that run when dependencies change

## Development Workflow

### Tool Management
Tools are managed via `mise` (configured in `dot_config/mise/config.toml`):
- Node.js, Bun for JavaScript development
- Python tools via pipx
- CLI utilities and development tools

### Git Configuration
Uses delta as pager with VSCode as default editor. Comprehensive git aliases and abbreviations for efficient workflow.

### Shell Configuration
- History management with deduplication
- Auto-launch tmux in Alacritty/Rio terminals
- Extensive abbreviation system for command shortcuts

## Important Notes

- This repository contains personal configurations; be careful with sensitive data
- The `.github/copilot-instructions.md` contains AI interaction logging preferences
- Many configurations are cross-platform with conditional logic for OS-specific behavior
- The abbreviation system is extensive - check `dot_config/zabrze/config.yaml` for command shortcuts