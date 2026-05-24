package app

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/command"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/config"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/executil"
)

func (a *App) Dev(ctx context.Context, taskName string, rawArgs []string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, groupName, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	upOpts, err := cfg.DevcontainerUpOpts(groupName)
	if err != nil {
		return err
	}
	execOpts, err := cfg.DevcontainerExecOpts(groupName)
	if err != nil {
		return err
	}

	a.log.Infof("タスク '%s' で devcontainer を起動します", taskName)

	if !cfg.SkipDevcontainerUpIfRunning() || !a.isDevcontainerRunning(ctx, filepath.Base(taskDir)) {
		a.log.Infof("devcontainer を起動中...")
		if err := a.Runner.Run(ctx, executil.Command{
			Dir:    taskDir,
			Name:   "devcontainer",
			Args:   append([]string{"up"}, upOpts...),
			Stdout: a.Stdout,
			Stderr: a.Stderr,
		}); err != nil {
			return fmt.Errorf("devcontainer の起動に失敗しました: %w", err)
		}
	} else {
		a.log.Infof("devcontainer は既に起動しています")
	}

	commandArgs, display, err := a.resolveDevCommand(cfg, rawArgs)
	if err != nil {
		return err
	}
	if len(commandArgs) == 0 {
		a.log.Warnf("選択がキャンセルされました")
		return nil
	}

	a.log.Infof("コマンドを実行中: %s", display)
	if err := a.Runner.Run(ctx, executil.Command{
		Dir:    taskDir,
		Name:   "devcontainer",
		Args:   append(append([]string{"exec"}, execOpts...), commandArgs...),
		Stdin:  a.Stdin,
		Stdout: a.Stdout,
		Stderr: a.Stderr,
	}); err != nil {
		return fmt.Errorf("コマンドの実行に失敗しました: %w", err)
	}

	a.log.Successf("コマンドが正常に完了しました")
	return nil
}

func (a *App) Sync(ctx context.Context, taskName string, useAll bool, selectedRepos []string) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, groupName, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	repos := group.ExpandedRepos()
	if len(selectedRepos) > 0 {
		filtered := make([]string, 0, len(selectedRepos))
		for _, selected := range selectedRepos {
			found := false
			for _, repo := range repos {
				if filepath.Base(repo) == selected {
					filtered = append(filtered, repo)
					found = true
					break
				}
			}
			if !found {
				a.log.Warnf("リポジトリ '%s' は設定に存在しません", selected)
			}
		}
		if len(filtered) == 0 {
			return fmt.Errorf("有効なリポジトリが選択されていません")
		}
		repos = filtered
		a.log.Infof("選択されたリポジトリ: %d 個", len(repos))
	}

	if useAll {
		if err := executil.LookPath("rsync"); err != nil {
			return err
		}
		a.log.Infof("タスク '%s' の worktree をメインworktreeにrsyncで完全同期します", taskName)
	} else {
		a.log.Infof("タスク '%s' の worktree のHEADをメインworktreeにcheckout --detachします", taskName)
	}
	a.log.Infof("ディレクトリ: %s", taskDir)
	fmt.Fprintln(a.Stdout)

	successCount := 0
	failCount := 0
	for _, repo := range repos {
		repoName := filepath.Base(repo)
		worktreePath := filepath.Join(taskDir, repoName)
		if !dirExists(worktreePath) {
			a.log.Warnf("[%s] worktree が見つかりません: %s", repoName, worktreePath)
			failCount++
			continue
		}
		if !dirExists(repo) {
			a.log.Warnf("[%s] リポジトリディレクトリが見つかりません: %s", repoName, repo)
			failCount++
			continue
		}

		a.log.Infof("[%s] 同期中...", repoName)
		head, err := a.Git.CurrentHEAD(ctx, worktreePath)
		if err != nil {
			a.log.Errorf("[%s] HEAD の取得に失敗しました: %v", repoName, err)
			failCount++
			continue
		}
		if err := a.Git.CheckoutDetach(ctx, repo, head); err != nil {
			a.log.Errorf("[%s] checkout --detach に失敗しました: %v", repoName, err)
			failCount++
			continue
		}

		if useAll {
			if err := a.Runner.Run(ctx, executil.Command{
				Name:   "rsync",
				Args:   []string{"-a", "--exclude", ".git", worktreePath + "/", repo + "/"},
				Stdout: a.Stdout,
				Stderr: a.Stderr,
			}); err != nil {
				a.log.Errorf("[%s] rsync に失敗しました: %v", repoName, err)
				failCount++
				continue
			}
			a.log.Successf("[%s] 完全同期完了: %s", repoName, repo)
		} else {
			a.log.Successf("[%s] checkout --detach 完了: %s", repoName, repo)
		}
		successCount++
	}

	fmt.Fprintln(a.Stdout)
	a.log.Infof("完了: 成功 %d / 失敗 %d", successCount, failCount)
	if failCount > 0 {
		return fmt.Errorf("一部のリポジトリの同期に失敗しました")
	}

	a.log.Successf("すべてのリポジトリの同期が完了しました")
	return nil
}

func (a *App) Remove(ctx context.Context, taskName string, force bool) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}

	taskDir, groupName, err := a.findTask(cfg, taskName)
	if err != nil {
		return err
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	a.log.Warnf("タスク '%s' の worktree を削除します", taskName)
	a.log.Infof("ディレクトリ: %s", taskDir)
	if force {
		a.log.Warnf("強制削除モード: 削除失敗時に権限を無視した削除を試行します")
	}
	fmt.Fprintln(a.Stdout)

	ok, err := command.Confirm(a.Stdin, a.Stdout, "本当に削除しますか? [y/N] ")
	if err != nil {
		return err
	}
	if !ok {
		a.log.Infof("キャンセルしました")
		return nil
	}

	successCount := 0
	failCount := 0
	for _, repo := range group.ExpandedRepos() {
		repoName := filepath.Base(repo)
		worktreePath := filepath.Join(taskDir, repoName)
		if !dirExists(worktreePath) {
			continue
		}

		a.log.Infof("[%s] worktree を削除中...", repoName)
		if err := a.Git.WorktreeRemove(ctx, repo, worktreePath); err == nil {
			a.log.Successf("[%s] worktree を削除しました", repoName)
			successCount++
			continue
		}

		if force {
			if err := os.RemoveAll(worktreePath); err == nil {
				a.log.Warnf("[%s] git worktree remove 失敗。ディレクトリを強制削除しました", repoName)
				successCount++
				continue
			}
			if err := a.trySudoRemove(ctx, worktreePath); err == nil {
				a.log.Warnf("[%s] git worktree remove 失敗。sudo で強制削除しました", repoName)
				successCount++
				continue
			}
		}

		a.log.Errorf("[%s] worktree の削除に失敗しました", repoName)
		failCount++
	}

	a.log.Infof("git worktree の登録情報をクリーンアップ中...")
	for _, repo := range group.ExpandedRepos() {
		if !dirExists(repo) {
			continue
		}
		_ = a.Git.WorktreePrune(ctx, repo)
		a.log.Infof("[%s] git worktree prune を実行しました", filepath.Base(repo))
	}

	if dirExists(taskDir) {
		if entries, err := os.ReadDir(taskDir); err == nil && len(entries) > 0 {
			if err := os.RemoveAll(taskDir); err == nil {
				a.log.Successf("残存ディレクトリを削除しました: %s", taskDir)
			} else {
				a.log.Errorf("残存ディレクトリの削除に失敗しました: %s", taskDir)
				failCount++
			}
		}
	}

	a.log.Infof("完了: 成功 %d / 失敗 %d", successCount, failCount)
	if failCount > 0 {
		return fmt.Errorf("一部の削除に失敗しました")
	}

	return nil
}

func (a *App) resolveDevCommand(cfg *config.Config, rawArgs []string) ([]string, string, error) {
	if len(rawArgs) > 0 {
		if len(rawArgs) == 1 {
			if mapped, ok := cfg.DevCommands[rawArgs[0]]; ok {
				return []string{"/bin/sh", "-lc", mapped}, mapped, nil
			}
		}
		return rawArgs, strings.Join(rawArgs, " "), nil
	}

	if len(cfg.DevCommands) == 0 {
		return nil, "", fmt.Errorf("実行するコマンドを指定してください（設定ファイルに [dev_commands] を追加するか、引数で直接指定）")
	}

	names := make([]string, 0, len(cfg.DevCommands))
	for name := range cfg.DevCommands {
		names = append(names, name)
	}
	slices.Sort(names)

	items := make([]command.Item, 0, len(names))
	for _, name := range names {
		items = append(items, command.Item{
			Label:       name,
			Description: cfg.DevCommands[name],
		})
	}

	selected, err := command.Select(items)
	if err != nil {
		if err == command.ErrCanceled {
			return nil, "", nil
		}
		return nil, "", err
	}

	return []string{"/bin/sh", "-lc", selected.Description}, selected.Description, nil
}

func (a *App) isDevcontainerRunning(ctx context.Context, containerName string) bool {
	if err := executil.LookPath("docker"); err != nil {
		return false
	}

	output, err := a.Runner.Output(ctx, executil.Command{
		Name: "docker",
		Args: []string{"ps", "--format", "{{.Names}}"},
	})
	if err != nil {
		return false
	}

	return strings.Contains(output, containerName)
}

func (a *App) trySudoRemove(ctx context.Context, target string) error {
	if err := executil.LookPath("sudo"); err != nil {
		return err
	}
	return a.Runner.Run(ctx, executil.Command{
		Name:   "sudo",
		Args:   []string{"-n", "rm", "-rf", target},
		Stdout: a.Stdout,
		Stderr: a.Stderr,
	})
}

func (a *App) ResolveTaskNames(ctx context.Context) ([]string, error) {
	tasks, err := a.ListTasks(ctx)
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(tasks))
	for _, task := range tasks {
		names = append(names, task.Name)
	}
	return names, nil
}

func (a *App) ResolveRepoNamesForTask(ctx context.Context, taskName string) ([]string, error) {
	cfg, err := a.loadConfig()
	if err != nil {
		return nil, err
	}

	taskDir, _, err := a.findTask(cfg, taskName)
	if err != nil {
		return nil, err
	}

	dirs, err := visibleDirectories(taskDir)
	if err != nil {
		return nil, err
	}

	names := make([]string, 0, len(dirs))
	for _, dir := range dirs {
		names = append(names, filepath.Base(dir))
	}
	return names, nil
}

func (a *App) ResolveRepoNamesForGroup(ctx context.Context, groupName string) ([]string, error) {
	cfg, err := a.loadConfig()
	if err != nil {
		return nil, err
	}

	if groupName == "" {
		groupName = cfg.DefaultGroupName()
	}
	group, err := cfg.Group(groupName)
	if err != nil {
		return nil, err
	}

	names := make([]string, 0, len(group.Repos))
	for _, repo := range group.ExpandedRepos() {
		names = append(names, filepath.Base(repo))
	}
	slices.Sort(names)
	return names, nil
}
