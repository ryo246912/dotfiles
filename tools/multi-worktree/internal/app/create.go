package app

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/pathutil"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/scaffold"
)

type CreateOptions struct {
	TaskName      string
	Group         string
	FromBranch    string
	DefaultBranch bool
}

type RecreateOptions struct {
	TaskName      string
	Group         string
	FromBranch    string
	DefaultBranch bool
}

func (a *App) Create(ctx context.Context, opts CreateOptions) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}
	if opts.FromBranch != "" && opts.DefaultBranch {
		return fmt.Errorf("--from/--branch と --default-branch は同時に指定できません")
	}

	groupName := opts.Group
	if groupName == "" {
		groupName = cfg.DefaultGroupName()
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	repos := group.ExpandedRepos()
	if len(repos) == 0 {
		return fmt.Errorf("グループ '%s' にリポジトリが設定されていません", groupName)
	}

	a.log.Infof("対象リポジトリ: %d 個", len(repos))
	a.fetchRepos(ctx, repos)

	baseLabel := "各リポジトリのデフォルトブランチ"
	if opts.FromBranch != "" {
		baseLabel = opts.FromBranch
	}
	a.log.Infof("タスク '%s' の worktree を作成します (新規ブランチ: %s, ベース: %s, グループ: %s)", opts.TaskName, opts.TaskName, baseLabel, groupName)

	worktreeBaseDir, err := cfg.WorktreeBaseDir(groupName, opts.TaskName)
	if err != nil {
		return err
	}
	a.log.Infof("作成先: %s", worktreeBaseDir)
	if err := os.MkdirAll(worktreeBaseDir, 0o755); err != nil {
		return err
	}

	successCount := 0
	failCount := 0
	for _, repo := range repos {
		if !dirExists(repo) {
			a.log.Warnf("リポジトリが見つかりません: %s", repo)
			failCount++
			continue
		}

		repoName := filepath.Base(repo)
		worktreePath := filepath.Join(worktreeBaseDir, repoName)
		a.log.Infof("[%s] worktree を作成中...", repoName)
		if err := a.Git.CreateWorktree(ctx, repo, worktreePath, opts.TaskName, opts.FromBranch); err != nil {
			a.log.Errorf("[%s] worktree の作成に失敗しました: %v", repoName, err)
			failCount++
			continue
		}

		a.log.Successf("[%s] worktree を作成しました: %s (ブランチ: %s)", repoName, worktreePath, opts.TaskName)
		successCount++
	}

	if successCount > 0 {
		if err := a.ensureTaskSupportFiles(ctx, opts.TaskName, worktreeBaseDir, repos); err != nil {
			return err
		}
	}

	a.log.Infof("完了: 成功 %d / 失敗 %d", successCount, failCount)
	if failCount > 0 {
		return fmt.Errorf("一部の worktree の作成に失敗しました")
	}

	a.log.Successf("すべての worktree が正常に作成されました")
	return nil
}

func (a *App) Recreate(ctx context.Context, opts RecreateOptions) error {
	cfg, err := a.loadConfig()
	if err != nil {
		return err
	}
	if opts.FromBranch != "" && opts.DefaultBranch {
		return fmt.Errorf("--from/--branch と --default-branch は同時に指定できません")
	}

	groupName := opts.Group
	if groupName == "" {
		if _, detectedGroup, err := a.findTask(cfg, opts.TaskName); err == nil {
			groupName = detectedGroup
		} else {
			groupName = cfg.DefaultGroupName()
		}
	}

	group, err := cfg.Group(groupName)
	if err != nil {
		return err
	}

	repos := group.ExpandedRepos()
	if len(repos) == 0 {
		return fmt.Errorf("グループ '%s' にリポジトリが設定されていません", groupName)
	}

	worktreeBaseDir, err := cfg.WorktreeBaseDir(groupName, opts.TaskName)
	if err != nil {
		return err
	}

	a.log.Infof("タスク '%s' の欠損 worktree を補充し、task 設定を再生成します (グループ: %s)", opts.TaskName, groupName)
	a.log.Infof("対象ディレクトリ: %s", worktreeBaseDir)
	if err := os.MkdirAll(worktreeBaseDir, 0o755); err != nil {
		return err
	}

	var missingRepos []string
	var missingPaths []string
	skipCount := 0
	failCount := 0

	for _, repo := range repos {
		if !dirExists(repo) {
			a.log.Warnf("リポジトリが見つかりません: %s", repo)
			failCount++
			continue
		}

		repoName := filepath.Base(repo)
		worktreePath := filepath.Join(worktreeBaseDir, repoName)
		if pathExists(worktreePath) {
			a.log.Infof("[%s] 既存の path を保持します: %s", repoName, worktreePath)
			skipCount++
			continue
		}

		missingRepos = append(missingRepos, repo)
		missingPaths = append(missingPaths, worktreePath)
	}

	if len(missingRepos) > 0 {
		a.log.Infof("不足している repo worktree を作成するため fetch を実行します")
		a.fetchRepos(ctx, missingRepos)
	} else {
		a.log.Infof("不足している repo worktree はありません")
	}

	createdCount := 0
	for idx := range missingRepos {
		repoName := filepath.Base(missingRepos[idx])
		a.log.Infof("[%s] worktree を作成中...", repoName)
		if err := a.Git.CreateWorktree(ctx, missingRepos[idx], missingPaths[idx], opts.TaskName, opts.FromBranch); err != nil {
			a.log.Errorf("[%s] worktree の作成に失敗しました: %v", repoName, err)
			failCount++
			continue
		}
		a.log.Successf("[%s] worktree を作成しました: %s (ブランチ: %s)", repoName, missingPaths[idx], opts.TaskName)
		createdCount++
	}

	if err := a.ensureTaskSupportFiles(ctx, opts.TaskName, worktreeBaseDir, repos); err != nil {
		return err
	}

	a.log.Infof("recreate 完了: 作成 %d / スキップ %d / 失敗 %d", createdCount, skipCount, failCount)
	if failCount > 0 {
		return fmt.Errorf("一部の補充に失敗しました")
	}

	a.log.Successf("タスク '%s' の欠損補充が完了しました", opts.TaskName)
	return nil
}

func (a *App) fetchRepos(ctx context.Context, repos []string) {
	type result struct {
		repo string
		err  error
	}

	a.log.Infof("全リポジトリを並列 fetch 中...")

	results := make([]result, len(repos))
	var wg sync.WaitGroup
	for idx, repo := range repos {
		wg.Add(1)
		go func(index int, repoPath string) {
			defer wg.Done()
			results[index] = result{
				repo: repoPath,
				err:  a.Git.Fetch(ctx, repoPath),
			}
		}(idx, repo)
	}
	wg.Wait()

	successCount := 0
	failCount := 0
	for _, result := range results {
		repoName := filepath.Base(result.repo)
		if result.err == nil {
			a.log.Successf("[%s] fetch 完了", repoName)
			successCount++
			continue
		}
		a.log.Warnf("[%s] fetch に失敗しました（続行します）", repoName)
		failCount++
	}

	a.log.Infof("fetch 完了: 成功 %d / 失敗 %d", successCount, failCount)
}

func (a *App) ensureTaskSupportFiles(ctx context.Context, taskName, taskRootDir string, repos []string) error {
	created, err := a.Git.EnsureTaskRootRepo(ctx, taskName, taskRootDir)
	if err != nil {
		return err
	}
	if created {
		a.log.Successf("task root の synthetic git repository を初期化しました: %s", taskRootDir)
	} else {
		a.log.Infof("task root の synthetic git repository を確認しました: %s", taskRootDir)
	}
	a.log.Infof("task root ブランチ: %s", pathutil.TaskRootBranchName(taskName))

	templatePath := filepath.Join(pathutil.Expand("~/.config/devcontainer"), "devcontainer.json")
	a.log.Infof("devcontainer.json を生成中...")
	if err := scaffold.GenerateDevcontainer(taskName, taskRootDir, templatePath, repos); err != nil {
		return err
	}
	a.log.Successf("devcontainer.json を生成しました: %s", filepath.Join(taskRootDir, ".devcontainer", "devcontainer.json"))

	if err := scaffold.WriteClaudeSettings(taskRootDir); err != nil {
		return err
	}
	a.log.Successf(".claude/settings.local.json を生成しました: %s", filepath.Join(taskRootDir, ".claude", "settings.local.json"))

	return nil
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
