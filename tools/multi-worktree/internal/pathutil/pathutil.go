package pathutil

import (
	"os"
	"path/filepath"
	"strings"
)

func Expand(path string) string {
	if path == "" {
		return path
	}

	home, err := os.UserHomeDir()
	if err != nil {
		home = os.Getenv("HOME")
	}

	switch {
	case path == "~":
		path = home
	case strings.HasPrefix(path, "~/"):
		path = filepath.Join(home, path[2:])
	}

	if home != "" {
		path = strings.ReplaceAll(path, "$HOME", home)
	}

	return path
}

func Clean(path string) string {
	return filepath.Clean(Expand(path))
}

func TaskDirName(taskName string) string {
	return strings.ReplaceAll(taskName, "/", "-")
}

func TaskRootBranchName(taskName string) string {
	return "multi-worktree-" + taskName
}
