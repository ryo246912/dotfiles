package executil

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
)

type Command struct {
	Dir    string
	Name   string
	Args   []string
	Env    []string
	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer
}

type Runner interface {
	Run(context.Context, Command) error
	Output(context.Context, Command) (string, error)
	CombinedOutput(context.Context, Command) (string, error)
}

type OSRunner struct{}

func (OSRunner) Run(ctx context.Context, command Command) error {
	cmd := prepare(ctx, command)
	return cmd.Run()
}

func (OSRunner) Output(ctx context.Context, command Command) (string, error) {
	cmd := prepare(ctx, command)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	output := strings.TrimRight(stdout.String(), "\n")
	if err != nil {
		return output, fmt.Errorf("%w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return output, nil
}

func (OSRunner) CombinedOutput(ctx context.Context, command Command) (string, error) {
	cmd := prepare(ctx, command)
	output, err := cmd.CombinedOutput()
	trimmed := strings.TrimRight(string(output), "\n")
	if err != nil {
		return trimmed, fmt.Errorf("%w: %s", err, trimmed)
	}
	return trimmed, nil
}

func prepare(ctx context.Context, command Command) *exec.Cmd {
	cmd := exec.CommandContext(ctx, command.Name, command.Args...)
	cmd.Dir = command.Dir
	if len(command.Env) > 0 {
		cmd.Env = append(cmd.Env, command.Env...)
	}
	cmd.Stdin = command.Stdin
	cmd.Stdout = command.Stdout
	cmd.Stderr = command.Stderr
	return cmd
}

func LookPath(name string) error {
	if _, err := exec.LookPath(name); err != nil {
		return fmt.Errorf("%s コマンドが見つかりません", name)
	}
	return nil
}
