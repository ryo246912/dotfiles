# opensessions AI Agent Support and Mechanism

## Supported AI Agents
opensessions standardly monitors the following agents:
- **Claude Code**: Watches JSONL logs in `~/.claude/projects/`.
- **Codex (Symphony)**: Watches session files in `~/.codex/sessions/`.
- **Amp**: Watches `~/.local/share/amp/threads/*.json`.
- **OpenCode**: Monitors SQLite database `opencode.db`.
- **Pi**: Internal watcher implementation.

## Principles of Operation
The core mechanism is based on **Passive Watching**:
1. **Filesystem Watch**: It uses OS features (like `fs.watch`) to monitor agent log directories.
2. **State Analysis**: It parses logs to determine states like `running`, `waiting`, `done`, or `error`.
3. **CWD Mapping**: It extracts the working directory from logs and maps it to tmux sessions to show status icons in the correct place.

## Compatibility with ccmanager
It is fully compatible with `ccmanager`. Since `opensessions` watches the files produced by the agents rather than managing the agent processes themselves, it doesn't matter how the agent was started (directly or via a manager like `ccmanager`).
