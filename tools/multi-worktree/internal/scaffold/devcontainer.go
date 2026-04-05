package scaffold

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/pathutil"
)

func GenerateDevcontainer(taskName, taskRootDir, templatePath string, repos []string) error {
	templatePath = pathutil.Clean(templatePath)
	data, err := os.ReadFile(templatePath)
	if err != nil {
		return fmt.Errorf("ベーステンプレートが見つかりません: %w", err)
	}

	var payload map[string]any
	if err := json.Unmarshal(stripJSONComments(data), &payload); err != nil {
		return fmt.Errorf("devcontainer テンプレートの解析に失敗しました: %w", err)
	}

	taskRootDir, err = filepath.Abs(taskRootDir)
	if err != nil {
		return fmt.Errorf("task root の絶対パス解決に失敗しました: %w", err)
	}

	mounts, err := normalizeMounts(payload["mounts"])
	if err != nil {
		return err
	}

	worktreeName := "multi-worktree-" + pathutil.TaskDirName(taskName)
	for _, repo := range repos {
		repo = pathutil.Clean(repo)
		repoName := filepath.Base(repo)
		worktreePath := filepath.Join(taskRootDir, repoName)
		if _, err := os.Stat(worktreePath); err != nil {
			continue
		}
		if _, err := os.Stat(repo); err != nil {
			continue
		}

		mounts = append(mounts,
			fmt.Sprintf("type=bind,source=%s,target=/workspaces/%s/%s", worktreePath, worktreeName, repoName),
			fmt.Sprintf("type=bind,source=%s,target=%s", repo, repo),
		)
	}

	payload["mounts"] = mounts
	payload["workspaceFolder"] = "/workspaces/" + worktreeName
	payload["name"] = "Multi-worktree: " + taskName

	out, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return fmt.Errorf("devcontainer.json の生成に失敗しました: %w", err)
	}
	out = append(out, '\n')

	targetDir := filepath.Join(taskRootDir, ".devcontainer")
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf(".devcontainer ディレクトリを作成できません: %w", err)
	}

	targetFile := filepath.Join(targetDir, "devcontainer.json")
	if err := os.WriteFile(targetFile, out, 0o644); err != nil {
		return fmt.Errorf("devcontainer.json の書き込みに失敗しました: %w", err)
	}

	return nil
}

func WriteClaudeSettings(taskRootDir string) error {
	targetDir := filepath.Join(taskRootDir, ".claude")
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf(".claude ディレクトリを作成できません: %w", err)
	}

	const payload = `{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "CURRENT_DIR=$(basename \"$PWD\"); ssh -F ~/.config/ssh/config -o ConnectTimeout=2 -o StrictHostKeyChecking=no mac-host \"if [ -n \\\"$TMUX\\\" ]; then macos-notify-cli --title \\\"Claude Code\\\" --message \\\"${CURRENT_DIR}が確認待ちです\\\" --sound Glass --current-tmux; else macos-notify-cli --title \\\"Claude Code\\\" --message \\\"${CURRENT_DIR}が確認待ちです\\\" --sound Glass; fi\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "CURRENT_DIR=$(basename \"$PWD\"); ssh -F ~/.config/ssh/config -o ConnectTimeout=2 -o StrictHostKeyChecking=no mac-host \"if [ -n \\\"$TMUX\\\" ]; then macos-notify-cli --title \\\"Claude Code\\\" --message \\\"${CURRENT_DIR}で作業が完了しました\\\" --sound Hero --current-tmux; else macos-notify-cli --title \\\"Claude Code\\\" --message \\\"${CURRENT_DIR}で作業が完了しました\\\" --sound Hero; fi\""
          }
        ]
      }
    ]
  }
}
`

	targetFile := filepath.Join(targetDir, "settings.local.json")
	return os.WriteFile(targetFile, []byte(payload), 0o644)
}

func normalizeMounts(value any) ([]string, error) {
	if value == nil {
		return []string{}, nil
	}

	switch mounts := value.(type) {
	case []string:
		return mounts, nil
	case []any:
		result := make([]string, 0, len(mounts))
		for _, mount := range mounts {
			str, ok := mount.(string)
			if !ok {
				return nil, fmt.Errorf("mounts に非文字列の値が含まれています")
			}
			result = append(result, str)
		}
		return result, nil
	default:
		return nil, fmt.Errorf("mounts は配列である必要があります")
	}
}

func stripJSONComments(input []byte) []byte {
	var out strings.Builder
	out.Grow(len(input))

	inString := false
	escape := false
	lineComment := false
	blockComment := false

	for i := 0; i < len(input); i++ {
		ch := input[i]
		next := byte(0)
		if i+1 < len(input) {
			next = input[i+1]
		}

		if lineComment {
			if ch == '\n' {
				lineComment = false
				out.WriteByte(ch)
			}
			continue
		}

		if blockComment {
			if ch == '*' && next == '/' {
				blockComment = false
				i++
			}
			continue
		}

		if inString {
			out.WriteByte(ch)
			if escape {
				escape = false
				continue
			}
			if ch == '\\' {
				escape = true
				continue
			}
			if ch == '"' {
				inString = false
			}
			continue
		}

		if ch == '"' {
			inString = true
			out.WriteByte(ch)
			continue
		}

		if ch == '/' && next == '/' {
			lineComment = true
			i++
			continue
		}
		if ch == '/' && next == '*' {
			blockComment = true
			i++
			continue
		}

		out.WriteByte(ch)
	}

	return []byte(out.String())
}
