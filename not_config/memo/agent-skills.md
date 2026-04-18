# Agent Skills Management

This document explains the strategy for managing AI agent skills in this repository.

## Management Strategy

We use two primary tools to manage agent skills, depending on their source and purpose.

### 1. Internal & Custom Skills (via rulesync)

- **Source of Truth**: `dot_config/rulesync/exact_dot_rulesync/skills/`
- **Tool**: [rulesync](https://github.com/dyoshikawa/rulesync)
- **Purpose**: Managing personal skills, project-specific custom skills, and cross-agent AI rules.
- **Workflow**:
  - Edit skills in `dot_config/rulesync/exact_dot_rulesync/skills/`.
  - Run `mise run rulesync-generate` to synchronize these skills to the appropriate agent directories (e.g., `.claude/skills/`, `.codex/skills/`).

### 2. External & Community Skills (via npx skills / gh skill)

- **Source of Truth**: `skills-lock.json`
- **Tool**: [vercel-labs/skills](https://github.com/vercel-labs/skills) or `gh skill` (GitHub CLI >= 2.90.0)
- **Purpose**: Managing external skills from GitHub repositories with version locking.
- **Workflow**:
  - **Install a new skill**: `npx skills add <owner/repo>` (this updates `skills-lock.json`).
  - **Restore skills**: `mise run skills-install` (runs `npx skills experimental_install`).
  - **Update skills**: `mise run skills-update` (runs `npx skills update -y`).
  - **Search/Preview**: Use `gh skill search` and `gh skill preview` for community skills.

## Comparison

| Feature         | rulesync (Internal)   | npx skills (External)     |
| :-------------- | :-------------------- | :------------------------ |
| **Storage**     | `dot_config/rulesync` | `skills-lock.json`        |
| **Lockfile**    | No (Git managed)      | Yes (`skills-lock.json`)  |
| **Best for**    | Custom/Private skills | Third-party/Public skills |
| **Cross-Agent** | Rules & Skills        | Skills only               |

## Note on .gitignore

Directories for individual agents (e.g., `.claude/`, `.agents/`) are ignored by Git.
Skills managed by `npx skills` are restored from the lockfile, while skills managed by `rulesync` are generated from the source files.
