package main

import (
	"os"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/cli"
)

func main() {
	cmd := cli.NewRootCommand(os.Stdin, os.Stdout, os.Stderr)
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
