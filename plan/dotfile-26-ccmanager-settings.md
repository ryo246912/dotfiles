# DOTFILE-26 ccmanager Settings Improvements

## Overview

- Add the missing `codex` and `copilot` entries around `ccmanager` and shell abbreviations without upgrading `ccmanager`.
- Add direct `devcontainer up` / `devcontainer exec` abbreviations that match the commands used by `ccmanager`.
- Make `devc-up-wrapper` recreate an existing devcontainer when the build inputs in `~/.config/devcontainer` changed.
- Reuse the versions already tracked in this repository instead of referring to upstream latest releases.

## Purpose and Scope

- Make `ccmanager` presets cover the same AI tools already used elsewhere in the repo.
- Fill the gap in `zabrze` abbreviations where `copilot` exists but `codex` does not.
- Add the day-to-day `devcontainer up` / `devcontainer exec` commands as reusable abbreviations.
- Keep devcontainer rebuild behavior aligned with config updates so that a changed `Dockerfile` / `mise.toml` is reflected on the next `devcontainer up`.
- Keep the change limited to repo-managed config and plan artifacts.
- Do not upgrade `ccmanager` or change unrelated AI tool configuration.

## Requirements

### Functional Requirements

- Add `codex` and `copilot` entries to the `ccmanager` preset configuration in [`dot_config/ccmanager/config.json`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/ccmanager/config.json).
- Add the missing `codex` abbreviations to [`dot_config/zabrze/ai.toml`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/zabrze/ai.toml).
- Add a `ccmanager devcontainer(codex)` abbreviation that mirrors the existing `claude` / `gemini` / `copilot` patterns.
- Add direct `devcontainer up` / `devcontainer exec` abbreviations that reuse the same config path as the `ccmanager` snippets.
- Update [`dot_local/bin/executable_devc-up-wrapper`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_local/bin/executable_devc-up-wrapper) so it removes a matching existing devcontainer when the configured build inputs are newer than that container.
- Reuse the existing command forms already documented in [`dot_config/multi-worktree/config.toml.sample`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/multi-worktree/config.toml.sample): `copilot --yolo` and `codex --yolo`.

### Non-Functional Requirements

- Preserve the existing command naming and trigger style in `zabrze`.
- Keep JSON and TOML valid and formatted according to repo conventions.
- Keep the wrapper implementation shell-only and lightweight so it remains usable from the existing `ccmanager` command flow.
- Avoid introducing config that depends on newer `ccmanager` behavior than the currently tracked version.

### Constraints

- Use the currently tracked versions in the repo:
  - `npm:ccmanager = 3.1.0`
  - `aqua:openai/codex = 0.110.0`
  - `github:github/copilot-cli = 1.0.2`
- Do not switch to "latest" or change the pinned versions in [`dot_config/mise/config.toml`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/mise/config.toml) / [`dot_config/devcontainer/mise.toml`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/devcontainer/mise.toml).
- Work only within this repository copy.

## Implementation Approach

### 1. Update ccmanager presets

- Extend [`dot_config/ccmanager/config.json`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/ccmanager/config.json) with `Copilot` and `Codex` presets.
- Keep the current default preset unchanged.
- Prefer simple `command` + `args` entries unless the current config already proves a tool-specific `detectionStrategy` is needed.

### 2. Update AI abbreviations

- Extend [`dot_config/zabrze/ai.toml`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/zabrze/ai.toml) with:
  - `ccmanager devcontainer(codex)`
  - direct `devcontainer up`
  - direct `devcontainer exec`
  - global `codex`
  - global `codex --yolo`
- Review the shared `yl` suffix snippet and decide whether its context should include `codex`, based on the repo's existing `codex --yolo` usage.

### 3. Update devcontainer rebuild detection

- Replace the pass-through [`dot_local/bin/executable_devc-up-wrapper`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_local/bin/executable_devc-up-wrapper) with a small shell wrapper that:
  - resolves the workspace folder / config path from the original `devcontainer up` arguments
  - checks the current config file plus sibling `Dockerfile` / `mise.toml`
  - compares those mtimes against any existing devcontainer matched by `devcontainer.local_folder` + `devcontainer.config_file`
  - removes the old container before delegating to `devcontainer up` when the build inputs are newer

### 4. Verify config consistency

- Cross-check the final commands against [`dot_config/multi-worktree/config.toml.sample`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/multi-worktree/config.toml.sample) and the current version pins.
- Validate JSON/TOML/shell syntax and inspect the resulting diff before moving to review.

## Files to Be Changed

- [`dot_config/ccmanager/config.json`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/ccmanager/config.json)
- [`dot_config/zabrze/ai.toml`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/zabrze/ai.toml)
- [`dot_local/bin/executable_devc-up-wrapper`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_local/bin/executable_devc-up-wrapper)
- [`plan/dotfile-26-ccmanager-settings.md`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/plan/dotfile-26-ccmanager-settings.md)

## Verification Method

- `jq . dot_config/ccmanager/config.json`
- `taplo format --check dot_config/zabrze/ai.toml`
- `rg -n "codex|copilot|ccmanager" dot_config/ccmanager/config.json dot_config/zabrze/ai.toml dot_config/multi-worktree/config.toml.sample`
- `bash -n dot_local/bin/executable_devc-up-wrapper`
- `shellcheck dot_local/bin/executable_devc-up-wrapper`
- mock-based wrapper validation covering "no matching container", "container newer than inputs", and "inputs newer than container"
- `git diff -- dot_config/ccmanager/config.json dot_config/zabrze/ai.toml dot_local/bin/executable_devc-up-wrapper plan/dotfile-26-ccmanager-settings.md`

## Risks and Open Questions

- [`dot_config/ccmanager/config.json`](/Users/ryo./Programming/ai/symphony/DOTFILE-26/dot_config/ccmanager/config.json) only shows a `detectionStrategy` example for Gemini. If `Codex` or `Copilot` need special detection behavior, that will need to be verified against the current `ccmanager 3.1.0` behavior before implementation.
- `zabrze` currently has no `codex` trigger convention, so trigger names must be chosen carefully to avoid collisions with existing short aliases.
- The rebuild detection relies on the devcontainer CLI's current `devcontainer.local_folder` / `devcontainer.config_file` labels for container lookup.
- `git fetch origin main` could not complete in this sandbox because the worktree git metadata lives outside the writable roots. Planning is unaffected, but that limitation may affect later git write operations in implementation.
