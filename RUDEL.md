# Rudel - Claude Code Session Analytics

[Rudel](https://github.com/obsessiondb/rudel) is a tool that provides analytics for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions. It gives you a dashboard with insights on your coding sessions — token usage, session duration, activity patterns, model usage, and more.

## Quick Start

### 1. Installation

Rudel is managed via `mise` in this repository. It is already included in the `mise.toml` and will be installed automatically when you run `mise install`.

If you need to install it manually:

```bash
npm install -g rudel
```

### 2. Login

Authenticate with your Rudel account (opens your browser):

```bash
rudel login
# Abbreviation: rdll
```

### 3. Enable Automatic Uploads

Register a Claude Code hook that automatically uploads your session transcript when a session ends:

```bash
rudel enable
# Abbreviation: rdle
```

## Commands

| Command         | Abbreviation | Description                                     |
| --------------- | ------------ | ----------------------------------------------- |
| `rudel login`   | `rdll`       | Authenticate with Rudel via browser.            |
| `rudel enable`  | `rdle`       | Register the auto-upload hook for Claude Code.  |
| `rudel disable` | `rdld`       | Remove the auto-upload hook.                    |
| `rudel upload`  | `rdlu`       | Interactively select projects for batch upload. |
| `rudel whoami`  | -            | Show the currently authenticated user.          |
| `rudel logout`  | -            | Clear stored credentials.                       |

## What Data Is Collected?

Each uploaded session includes:

- Session ID & timestamps
- User ID & organization ID
- Project path & package name
- Git context (repository, branch, SHA, remote)
- **Session transcript** (full prompt & response content)
- Sub-agent usage

## Security & Privacy

**Warning:** Rudel ingests full coding-agent session data. Transcripts and metadata may contain sensitive material, including source code, prompts, tool output, file contents, command output, URLs, and secrets.

Only enable Rudel on projects where you are comfortable uploading this data. Review the [Rudel Privacy Policy](https://rudel.ai/privacy-policy) for more details.

## Troubleshooting

If automatic uploads are not working, ensure the hook was correctly registered by checking your Claude Code hooks configuration. You can always manually upload sessions using `rudel upload`.
