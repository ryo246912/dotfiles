# Repository Best Practices Skill

## Context
This skill contains the current best practices for maintaining this dotfiles repository.

## Rules
- Always edit source files in `dot_*` or `not_config/`, never edit deployed files directly.
- Use `chezmoi apply` to deploy changes.
- All commits should be GPG-signed (configured automatically in the environment).
- Follow the modular structure for Zsh and mise configurations.
- Ensure cross-platform compatibility for macOS and Windows/WSL2.

## Maintenance
This file is automatically updated by the Claude Maintenance GitHub Action.
