package scaffold

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateDevcontainer(t *testing.T) {
	root := t.TempDir()
	templateDir := filepath.Join(root, "template")
	taskRoot := filepath.Join(root, "worktrees", "multi-worktree-feat-add-auth")
	repoRoot := filepath.Join(root, "repo-a")
	worktreeRepo := filepath.Join(taskRoot, "repo-a")

	for _, dir := range []string{templateDir, repoRoot, worktreeRepo} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	templatePath := filepath.Join(templateDir, "devcontainer.json")
	templateBody := `{
  // comment
  "name": "Base",
  "mounts": ["type=bind,source=/tmp/base,target=/tmp/base"]
}`
	if err := os.WriteFile(templatePath, []byte(templateBody), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := GenerateDevcontainer("feat/add-auth", taskRoot, templatePath, []string{repoRoot}); err != nil {
		t.Fatalf("GenerateDevcontainer() error = %v", err)
	}

	outputPath := filepath.Join(taskRoot, ".devcontainer", "devcontainer.json")
	data, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatal(err)
	}

	var payload map[string]any
	if err := json.Unmarshal(data, &payload); err != nil {
		t.Fatalf("generated json is invalid: %v", err)
	}

	if payload["workspaceFolder"] != "/workspaces/multi-worktree-feat-add-auth" {
		t.Fatalf("workspaceFolder = %v", payload["workspaceFolder"])
	}

	mounts, ok := payload["mounts"].([]any)
	if !ok || len(mounts) != 3 {
		t.Fatalf("mounts = %#v", payload["mounts"])
	}
}
