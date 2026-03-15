# DOTFILE-34 Neovim VSCode-like Settings

## Overview

- Bring the existing Neovim setup closer to the VSCode experience already described in `dot_config/vscode/settings.json`.
- Cover code navigation, cursor-word navigation, inline diagnostics, current-file task execution, and save-time formatting for the languages named in the ticket.
- Allow save hooks to be toggled interactively, so format-on-save can be turned on and off without editing config files.
- Write a Japanese implementation/result summary as `03-result.md`, including the new usage flow.
- Keep the implementation inside the current `lazy.nvim` plugin layout and avoid widening scope into unrelated editor changes.

## Current Snapshot

- The current branch already contains an in-progress implementation for the main Neovim behavior changes, while the Linear issue state is still `Todo`.
- Existing working-tree changes already add:
  - `pyright` and `terraformls` to the Mason/LSP setup, along with call-hierarchy fallback keymaps and inline diagnostic toggles
  - cursor-word search bootstrapping for `n` / `N`
  - a new `core.file_actions` module that resolves current-file lint/test/format commands and save hooks
  - a current-file action picker wired into the floating terminal UI
- The remaining work is primarily review-oriented:
  - verify the current diff against representative filetypes and headless startup
  - decide whether any implementation gaps remain after validation
  - document the shipped behavior in `03-result.md`
- Because of that mismatch, this plan is intentionally framed as a reconciliation and verification plan for the existing diff, not a from-scratch build plan.

## Requirements

### Functional Requirements

- Support definition/reference/implementation jumps for Go, TypeScript, Python, GraphQL, Terraform, and TOML-backed files.
- Provide a focused-word flow where the word under the cursor is visible and `n` / `N` can move through its occurrences without requiring a manual search setup every time.
- Render diagnostics inline in the buffer in a way that is closer to VSCode Error Lens than the current float-only flow.
- Make it easy to run lint, test, and format commands for the current file from inside Neovim.
- Run format-on-save and related save hooks for the languages that already have VSCode-side formatting expectations.
- Make the save hooks controllable interactively from within Neovim.
- Produce `03-result.md` in Japanese with the implemented behavior and usage.

### Non-Functional Requirements

- Reuse the current Neovim module split under `dot_config/nvim/lua/plugins/` and `dot_config/nvim/lua/core/`.
- Prefer project-local tools when running lint/test/format commands, and surface a clear notification when a command is not available.
- Keep keymaps consistent with the current comma leader setup and avoid breaking existing navigation habits.
- Keep plugin additions minimal and isolate new concerns into dedicated modules when that reduces coupling.
- Avoid adding new plugins when the same outcome can be achieved with the built-in Neovim APIs and the plugins already in this repo.

### Constraints

- The repository is a git worktree, and `git fetch` is blocked in this sandbox because the worktree metadata lives outside the writable roots.
- The current Neovim config does not pin plugin versions with `lazy-lock.json`, so any new plugin choice should be conservative.
- The current global tool set in `dot_config/mise/config.toml` includes Prettier, Taplo, Terraform, Node, Python, and Go-related tooling, but not every formatter/linter that would fully mirror the VSCode stack.
- Shell/network restrictions in this session make new plugin downloads hard to validate, so the implementation should prefer existing plugins and installed CLIs.

## Implementation Plan

### 1. Reconcile the current diff with the intended Neovim UX contract

- Audit the current Neovim modules that already own LSP, search, keymaps, terminal execution, and save hooks.
- Cross-reference the existing VSCode settings and extension list so the Neovim behavior targets the same user-visible outcomes.
- Identify which parts are already implemented in the working tree and which parts still need code changes after verification.

### 2. Review and complete LSP-backed code navigation

- Extend the current Mason/LSP setup beyond Go, GraphQL, TOML, and TypeScript so Python and Terraform are covered as first-class targets.
- Keep the existing `on_attach` pattern, but tighten the navigation contract around definitions, references, implementations, rename, code actions, and diagnostic movement.
- If the currently available APIs and servers support call hierarchy cleanly, expose incoming/outgoing call navigation; otherwise keep that part as an explicit fallback to definition/reference navigation.

### 3. Review cursor-word navigation and inline diagnostics

- Introduce a lightweight current-word highlighting/search bridge so the word under the cursor becomes the active search target for `n` / `N` when appropriate.
- Add or tune inline diagnostics so errors and warnings are visible directly in the edited buffer instead of only through floats.
- Keep diagnostic floats and next/previous navigation available as a secondary path.

### 4. Review context-aware command execution and save hooks

- Extend the existing floating terminal command runner so it can offer filetype-aware lint/test/format presets for the current buffer.
- Derive commands from the current file and repository context, preferring project-local executables and repo-native commands where possible.
- Add save-time formatting with built-in Neovim autocmds plus external CLIs already available in the environment.
- Add interactive enable/disable/toggle commands for save hooks.
- Align formatter defaults with the existing VSCode behavior for JavaScript, TypeScript, Python, YAML, JSON, TOML, and Terraform where practical.

### 5. Document the result for future use

- Summarize the implemented behavior, commands, and caveats in `03-result.md`.
- Keep the document in Japanese and focused on practical usage.

### 6. Verify editor startup and representative workflows

- Validate that Neovim still boots cleanly in headless mode after plugin changes.
- Smoke test representative Go, TypeScript, Python, Terraform, and TOML files for code navigation and diagnostics.
- Smoke test the current-file task runner and format-on-save flow on the languages most likely to hit the new code paths.

## Files Likely To Change

- `dot_config/nvim/lua/plugins/lsp.lua`
- `dot_config/nvim/lua/plugins/editor.lua`
- `dot_config/nvim/lua/plugins/terminal.lua`
- `dot_config/nvim/lua/core/keymaps.lua`
- `dot_config/nvim/lua/core/autocmds.lua`
- Potential shared helper modules under `dot_config/nvim/lua/core/` for diagnostics, formatting, or task command resolution
- Potential update to `dot_config/mise/config.toml` only if a global fallback tool is required and project-local discovery is not enough
- `02-implement.md`
- `03-result.md`

## Verification Method

- Run a headless Neovim startup check after the plugin graph changes.
- Validate representative language coverage for:
  - definition/reference/implementation jumps
  - cursor-word highlighting and `n` / `N` movement
  - inline diagnostic rendering
  - current-file task execution
  - save-time formatting
- Validate the interactive save-hook toggle behavior.
- Confirm `03-result.md` reflects the shipped behavior and keymaps/commands.
- Confirm the relevant worktree remains clean except for the intended ticket changes.

## Risks and Open Questions

- Cross-language "参照元/参照先" semantics vary by LSP server. Some servers cleanly support call hierarchy, while others may only guarantee definition/reference results.
- A generic current-file test runner is inherently heuristic. Some repositories will need per-project command overrides for ideal results.
- Matching VSCode's Python and JavaScript behavior may require additional tool discovery or optional global tool installs if project-local commands are not present.
- Python save-time formatting may need a project-local `ruff` installation when no global formatter is present.
- The branch already contains uncommitted Neovim changes, so any follow-up implementation must preserve those edits rather than rebuilding them.
