# Example Session

```
User: /workflow-review

Claude: I'll analyze this session and your CC configuration.

[Reads CLAUDE.md, .claude/settings.json]
[Queries claude-code-guide for relevant features]

Claude: Found 3 recommendations.

[AskUserQuestion]
## Recommendation: Add Bash permission for git commands

**Observation**: You approved `git status`, `git diff`, `git log` 12 times this session.
**Suggestion**: Add `Bash(git:*)` to allowed tools in settings.
**Benefit**: No more permission prompts for git commands.

**To apply**: Add to ~/.claude/settings.json:
  "permissions": { "allow": ["Bash(git:*)"] }

Options: [Apply this] [Skip] [Stop review]

User: Apply this

Claude: Here's the exact change:
[Shows JSON snippet to copy]

Moving to next recommendation...
```
