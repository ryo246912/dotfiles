# Transcript JSONL Format

Claude Code session transcripts are stored as JSONL (JSON Lines) files.

## File Location

```
~/.claude/projects/{encoded-cwd}/{session-id}.jsonl
```

Where `{encoded-cwd}` is the working directory with `/` replaced by `-`.

## Line Types

Each line is a JSON object with a `type` field:

### User Messages (`type: "user"`)
```json
{
  "type": "user",
  "userType": "external",
  "message": {
    "role": "user",
    "content": "user's input text"
  },
  "timestamp": "2026-01-18T14:32:44.979Z",
  "uuid": "..."
}
```

### Assistant Messages (`type: "assistant"`)
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {"type": "text", "text": "..."},
      {"type": "tool_use", "name": "Read", "input": {...}}
    ]
  },
  "timestamp": "...",
  "uuid": "..."
}
```

### Tool Results (`type: "user"` with tool_result)
```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [
      {"type": "tool_result", "tool_use_id": "...", "content": "..."}
    ]
  }
}
```

## Analysis Patterns

### Extract Tool Usage
```bash
grep '"tool_use"' transcript.jsonl | jq -r '.message.content[]? | select(.type=="tool_use") | .name' | sort | uniq -c | sort -rn
```

### Count Messages by Type
```bash
jq -r '.type' transcript.jsonl | sort | uniq -c
```

### Find User Prompts
```bash
jq -r 'select(.type=="user" and .userType=="external") | .message.content' transcript.jsonl
```

### Find Permission Approvals
Look for tool_result responses after tool_use requests.

## Key Fields for Analysis

| Field | Use |
|-------|-----|
| `type` | user/assistant message |
| `message.content[].type` | text/tool_use/tool_result |
| `message.content[].name` | Tool name (for tool_use) |
| `timestamp` | Timing analysis |
| `userType` | "external" = human, else system |
