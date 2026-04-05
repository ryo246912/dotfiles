package app

import (
	"cmp"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/config"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/executil"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/gitops"
)

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	reset  = "\033[0m"
)

type App struct {
	ConfigPath string
	Runner     executil.Runner
	Git        *gitops.Service
	Stdin      io.Reader
	Stdout     io.Writer
	Stderr     io.Writer
	log        logger
}

type TaskInfo struct {
	Name            string
	Group           string
	Path            string
	RepoCount       int
	HasDevcontainer bool
}

type logger struct {
	out io.Writer
	err io.Writer
}

func New(configPath string, stdin io.Reader, stdout, stderr io.Writer) *App {
	runner := executil.OSRunner{}
	return &App{
		ConfigPath: configPath,
		Runner:     runner,
		Git:        gitops.New(runner),
		Stdin:      stdin,
		Stdout:     stdout,
		Stderr:     stderr,
		log: logger{
			out: stdout,
			err: stderr,
		},
	}
}

func (a *App) loadConfig() (*config.Config, error) {
	cfg, err := config.Load(a.ConfigPath)
	if err != nil {
		if strings.Contains(err.Error(), "設定ファイルが見つかりません") {
			return nil, fmt.Errorf("%s\nサンプルを ~/.config/multi-worktree/config.toml へコピーして設定してください", err)
		}
		return nil, err
	}
	return cfg, nil
}

func (a *App) List(ctx context.Context) error {
	tasks, err := a.ListTasks(ctx)
	if err != nil {
		return err
	}

	for _, task := range tasks {
		hasDevcontainer := ""
		if task.HasDevcontainer {
			hasDevcontainer = "devcontainer"
		}
		fmt.Fprintf(a.Stdout, "%s\t%s\t%s\t%d repos\t%s\n", task.Name, task.Group, task.Path, task.RepoCount, hasDevcontainer)
	}

	return nil
}

func (a *App) ListTasks(ctx context.Context) ([]TaskInfo, error) {
	cfg, err := a.loadConfig()
	if err != nil {
		return nil, err
	}

	var tasks []TaskInfo
	for _, groupName := range cfg.GroupNames() {
		group, err := cfg.Group(groupName)
		if err != nil {
			return nil, err
		}

		baseDir, err := cfg.ResolveBaseDir(groupName)
		if err != nil {
			return nil, err
		}

		entries, err := os.ReadDir(baseDir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, err
		}

		prefix := group.WorktreePrefix + "-"
		for _, entry := range entries {
			if !entry.IsDir() || !strings.HasPrefix(entry.Name(), prefix) {
				continue
			}

			taskDir := filepath.Join(baseDir, entry.Name())
			repoCount, err := countVisibleDirectories(taskDir)
			if err != nil {
				return nil, err
			}

			fallback := strings.TrimPrefix(entry.Name(), prefix)
			taskName := a.taskNameFromDir(ctx, taskDir, fallback)
			tasks = append(tasks, TaskInfo{
				Name:            taskName,
				Group:           groupName,
				Path:            taskDir,
				RepoCount:       repoCount,
				HasDevcontainer: fileExists(filepath.Join(taskDir, ".devcontainer", "devcontainer.json")),
			})
		}
	}

	slices.SortFunc(tasks, func(left, right TaskInfo) int {
		if diff := cmp.Compare(left.Group, right.Group); diff != 0 {
			return diff
		}
		return cmp.Compare(left.Name, right.Name)
	})

	return tasks, nil
}

func (a *App) Status(ctx context.Context, taskName string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, _, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	a.log.Infof("タスク '%s' のステータス", taskName)
	a.log.Infof("ディレクトリ: %s", taskDir)
	fmt.Fprintln(a.Stdout)

	repoDirs, err := visibleDirectories(taskDir)
	if err != nil {
		return err
	}

	for _, repoDir := range repoDirs {
		if !a.Git.IsGitRepository(ctx, repoDir) {
			continue
		}

		repoName := filepath.Base(repoDir)
		fmt.Fprintf(a.Stdout, "%s=== %s ===%s\n", blue, repoName, reset)

		branch, err := a.Git.CurrentBranch(ctx, repoDir)
		if err != nil || branch == "" {
			branch = "unknown"
		}
		fmt.Fprintf(a.Stdout, "ブランチ: %s\n", branch)

		status, err := a.Git.StatusPorcelain(ctx, repoDir)
		if err != nil {
			return err
		}
		if status != "" {
			fmt.Fprintf(a.Stdout, "%s変更あり%s\n", yellow, reset)
			fmt.Fprintln(a.Stdout, status)
		} else {
			fmt.Fprintf(a.Stdout, "%s変更なし%s\n", green, reset)
		}

		fmt.Fprintln(a.Stdout)
		fmt.Fprintln(a.Stdout, "最新のコミット:")
		commits, err := a.Git.RecentCommits(ctx, repoDir, 3)
		if err != nil || commits == "" {
			fmt.Fprintln(a.Stdout, "コミット履歴なし")
		} else {
			fmt.Fprintln(a.Stdout, commits)
		}
		fmt.Fprintln(a.Stdout)
	}

	return nil
}

func (a *App) StatusMain(ctx context.Context, requestedGroup string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	groupName := requestedGroup
	if groupName == "" {
		groupName = cfg.DefaultGroupName()
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	repos := group.ExpandedRepos()
	if len(repos) == 0 {
		return fmt.Errorf("グループ '%s' のリポジトリが設定されていません", groupName)
	}

	a.log.Infof("グループ '%s' の各リポジトリ（デフォルトブランチ）のステータス", groupName)
	fmt.Fprintln(a.Stdout)

	for _, repo := range repos {
		repoName := filepath.Base(repo)
		fmt.Fprintf(a.Stdout, "%s=== %s ===%s\n", blue, repoName, reset)

		if !dirExists(repo) {
			fmt.Fprintf(a.Stdout, "%sディレクトリが見つかりません: %s%s\n\n", red, repo, reset)
			continue
		}

		branch, err := a.Git.CurrentBranch(ctx, repo)
		if err != nil || branch == "" {
			branch = "unknown"
		}
		defaultBranch := a.Git.DefaultBranch(ctx, repo)
		fmt.Fprintf(a.Stdout, "ブランチ: %s", branch)
		if defaultBranch != "" {
			fmt.Fprintf(a.Stdout, " (デフォルト: %s)", defaultBranch)
		}
		fmt.Fprintln(a.Stdout)

		status, err := a.Git.StatusPorcelain(ctx, repo)
		if err != nil {
			return err
		}
		if status != "" {
			fmt.Fprintf(a.Stdout, "%s変更あり%s\n", yellow, reset)
			fmt.Fprintln(a.Stdout, status)
		} else {
			fmt.Fprintf(a.Stdout, "%s変更なし%s\n", green, reset)
		}

		fmt.Fprintln(a.Stdout)
		fmt.Fprintln(a.Stdout, "最新のコミット:")
		commits, err := a.Git.RecentCommits(ctx, repo, 3)
		if err != nil || commits == "" {
			fmt.Fprintln(a.Stdout, "コミット履歴なし")
		} else {
			fmt.Fprintln(a.Stdout, commits)
		}
		fmt.Fprintln(a.Stdout)
	}

	return nil
}

func (a *App) CD(ctx context.Context, taskName, repoName string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, _, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	targetDir := taskDir
	if repoName != "" {
		targetDir = filepath.Join(taskDir, repoName)
		if !dirExists(targetDir) {
			return fmt.Errorf("リポジトリ '%s' の worktree が見つかりません: %s", repoName, targetDir)
		}
	}

	a.log.Infof("worktree ディレクトリに移動します: %s", targetDir)
	a.log.Successf("新しいシェルを起動します。exit で戻ります。")

	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}

	cmd := exec.CommandContext(ctx, shell)
	cmd.Dir = targetDir
	cmd.Stdin = a.Stdin
	cmd.Stdout = a.Stdout
	cmd.Stderr = a.Stderr
	return cmd.Run()
}

func (a *App) Open(ctx context.Context, taskName string) error {
	if err := executil.LookPath("code"); err != nil {
		return err
	}

	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, _, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	a.log.Infof("VSCode で worktree ディレクトリを開きます: %s", taskDir)
	if err := a.Runner.Run(ctx, executil.Command{
		Name:   "code",
		Args:   []string{taskDir},
		Stdout: a.Stdout,
		Stderr: a.Stderr,
	}); err != nil {
		return err
	}

	a.log.Successf("VSCode を起動しました")
	return nil
}

func (a *App) Exec(ctx context.Context, taskName string, rawArgs []string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, _, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	workDir, label, commandArgs, err := parseExecArgs(taskDir, rawArgs)
	if err != nil {
		return err
	}

	a.log.Infof("%s コマンド実行: %s", label, strings.Join(commandArgs, " "))
	a.log.Infof("ディレクトリ: %s", workDir)
	fmt.Fprintln(a.Stdout)

	if err := a.Runner.Run(ctx, executil.Command{
		Dir:    workDir,
		Name:   commandArgs[0],
		Args:   commandArgs[1:],
		Stdin:  a.Stdin,
		Stdout: a.Stdout,
		Stderr: a.Stderr,
	}); err != nil {
		return fmt.Errorf("コマンドが失敗しました: %w", err)
	}

	a.log.Successf("コマンドが正常に完了しました")
	return nil
}

func (a *App) ExecMain(ctx context.Context, requestedGroup, repoName string, rawArgs []string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	groupName := requestedGroup
	if groupName == "" {
		groupName = cfg.DefaultGroupName()
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	repoPath := ""
	for _, repo := range group.ExpandedRepos() {
		if filepath.Base(repo) == repoName {
			repoPath = repo
			break
		}
	}
	if repoPath == "" {
		return fmt.Errorf("リポジトリ '%s' がグループ '%s' に見つかりません", repoName, groupName)
	}
	if !dirExists(repoPath) {
		return fmt.Errorf("リポジトリディレクトリが見つかりません: %s", repoPath)
	}

	commandArgs := trimDoubleDash(rawArgs)
	if len(commandArgs) == 0 {
		return fmt.Errorf("実行するコマンドを指定してください")
	}

	a.log.Infof("[%s] コマンド実行 (main): %s", repoName, strings.Join(commandArgs, " "))
	a.log.Infof("ディレクトリ: %s", repoPath)
	fmt.Fprintln(a.Stdout)

	if err := a.Runner.Run(ctx, executil.Command{
		Dir:    repoPath,
		Name:   commandArgs[0],
		Args:   commandArgs[1:],
		Stdin:  a.Stdin,
		Stdout: a.Stdout,
		Stderr: a.Stderr,
	}); err != nil {
		return fmt.Errorf("コマンドが失敗しました: %w", err)
	}

	a.log.Successf("コマンドが正常に完了しました")
	return nil
}

func (a *App) findTask(cfg *config.Config, taskName string) (string, string, error) {
	for _, groupName := range cfg.GroupNames() {
		taskDir, err := cfg.WorktreeBaseDir(groupName, taskName)
		if err != nil {
			return "", "", err
		}
		if dirExists(taskDir) {
			return taskDir, groupName, nil
		}
	}
	return "", "", fmt.Errorf("タスク '%s' の worktree が見つかりません", taskName)
}

func (a *App) taskNameFromDir(ctx context.Context, taskRootDir, fallback string) string {
	if dirExists(filepath.Join(taskRootDir, ".git")) && a.Git.IsGitRepository(ctx, taskRootDir) {
		if branch, err := a.Git.CurrentBranch(ctx, taskRootDir); err == nil && strings.HasPrefix(branch, "multi-worktree-") {
			return strings.TrimPrefix(branch, "multi-worktree-")
		}
	}

	repoDirs, err := visibleDirectories(taskRootDir)
	if err == nil {
		for _, repoDir := range repoDirs {
			if !a.Git.IsGitRepository(ctx, repoDir) {
				continue
			}
			if branch, err := a.Git.CurrentBranch(ctx, repoDir); err == nil && branch != "" {
				return branch
			}
		}
	}

	return strings.ReplaceAll(fallback, "-", "/")
}

func visibleDirectories(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	dirs := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") {
			continue
		}
		dirs = append(dirs, filepath.Join(dir, entry.Name()))
	}
	slices.Sort(dirs)
	return dirs, nil
}

func countVisibleDirectories(dir string) (int, error) {
	dirs, err := visibleDirectories(dir)
	if err != nil {
		return 0, err
	}
	return len(dirs), nil
}

func parseExecArgs(taskDir string, rawArgs []string) (string, string, []string, error) {
	if len(rawArgs) == 0 {
		return "", "", nil, fmt.Errorf("実行するコマンドを指定してください")
	}

	workDir := taskDir
	label := "[root]"
	args := rawArgs

	if args[0] != "--" {
		candidate := filepath.Join(taskDir, args[0])
		if dirExists(candidate) {
			workDir = candidate
			label = "[" + args[0] + "]"
			args = args[1:]
		}
	}

	args = trimDoubleDash(args)
	if len(args) == 0 {
		return "", "", nil, fmt.Errorf("実行するコマンドを指定してください")
	}

	return workDir, label, args, nil
}

func trimDoubleDash(args []string) []string {
	if len(args) > 0 && args[0] == "--" {
		return args[1:]
	}
	return args
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func (l logger) Infof(format string, args ...any) {
	fmt.Fprintf(l.out, "%s[INFO]%s %s\n", blue, reset, fmt.Sprintf(format, args...))
}

func (l logger) Successf(format string, args ...any) {
	fmt.Fprintf(l.out, "%s[SUCCESS]%s %s\n", green, reset, fmt.Sprintf(format, args...))
}

func (l logger) Warnf(format string, args ...any) {
	fmt.Fprintf(l.out, "%s[WARN]%s %s\n", yellow, reset, fmt.Sprintf(format, args...))
}

func (l logger) Errorf(format string, args ...any) {
	fmt.Fprintf(l.err, "%s[ERROR]%s %s\n", red, reset, fmt.Sprintf(format, args...))
}
