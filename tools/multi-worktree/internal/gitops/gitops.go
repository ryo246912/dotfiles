package gitops

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/executil"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/pathutil"
)

type Service struct {
	Runner executil.Runner
}

func New(runner executil.Runner) *Service {
	return &Service{Runner: runner}
}

func (s *Service) Fetch(ctx context.Context, repo string) error {
	return s.Runner.Run(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: []string{"fetch", "origin"},
	})
}

func (s *Service) DefaultBranch(ctx context.Context, repo string) string {
	output, err := s.Runner.Output(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: []string{"symbolic-ref", "refs/remotes/origin/HEAD"},
	})
	if err == nil {
		output = strings.TrimSpace(strings.TrimPrefix(output, "refs/remotes/origin/"))
		if output != "" {
			return output
		}
	}

	for _, branch := range []string{"main", "master"} {
		if s.RefExists(ctx, repo, "refs/remotes/origin/"+branch) {
			return branch
		}
	}

	return "main"
}

func (s *Service) RefExists(ctx context.Context, repo, ref string) bool {
	err := s.Runner.Run(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: []string{"show-ref", "--verify", "--quiet", ref},
	})
	return err == nil
}

func (s *Service) CreateWorktree(ctx context.Context, repo, worktreePath, taskName, fromBranch string) error {
	resolvedBranch := taskName
	args := []string{"worktree", "add", worktreePath}

	switch {
	case s.RefExists(ctx, repo, "refs/heads/"+resolvedBranch):
		args = append(args, resolvedBranch)
	case s.RefExists(ctx, repo, "refs/remotes/origin/"+resolvedBranch):
		args = append(args, "-b", resolvedBranch, "origin/"+resolvedBranch)
	default:
		baseBranch := fromBranch
		if baseBranch == "" {
			baseBranch = s.DefaultBranch(ctx, repo)
		}

		baseRef := ""
		switch {
		case s.RefExists(ctx, repo, "refs/remotes/origin/"+baseBranch):
			baseRef = "origin/" + baseBranch
		case s.RefExists(ctx, repo, "refs/heads/"+baseBranch):
			baseRef = baseBranch
		default:
			return fmt.Errorf("ベースブランチ '%s' が見つかりません", baseBranch)
		}

		args = append(args, "-b", resolvedBranch, baseRef)
	}

	return s.Runner.Run(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: args,
	})
}

func (s *Service) EnsureTaskRootRepo(ctx context.Context, taskName, taskRootDir string) (bool, error) {
	gitDir := filepath.Join(taskRootDir, ".git")
	created := false

	if info, err := os.Stat(gitDir); err == nil && !info.IsDir() {
		return false, fmt.Errorf("task root の .git がディレクトリではありません: %s", gitDir)
	} else if err != nil && !os.IsNotExist(err) {
		return false, fmt.Errorf("task root の .git を確認できません: %w", err)
	}

	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		if err := s.Runner.Run(ctx, executil.Command{
			Dir:  taskRootDir,
			Name: "git",
			Args: []string{"init"},
		}); err != nil {
			return false, err
		}
		created = true
	}

	for _, args := range [][]string{
		{"config", "status.showUntrackedFiles", "no"},
		{"config", "advice.detachedHead", "false"},
	} {
		if err := s.Runner.Run(ctx, executil.Command{
			Dir:  taskRootDir,
			Name: "git",
			Args: args,
		}); err != nil {
			return created, err
		}
	}

	branchName := pathutil.TaskRootBranchName(taskName)
	if s.Runner.Run(ctx, executil.Command{
		Dir:  taskRootDir,
		Name: "git",
		Args: []string{"rev-parse", "--verify", "HEAD"},
	}) == nil {
		currentBranch, _ := s.CurrentBranch(ctx, taskRootDir)
		if currentBranch != branchName {
			if s.RefExists(ctx, taskRootDir, "refs/heads/"+branchName) {
				if err := s.switchBranch(ctx, taskRootDir, branchName, false); err != nil {
					return created, err
				}
			} else {
				if err := s.switchBranch(ctx, taskRootDir, branchName, true); err != nil {
					return created, err
				}
			}
		}
		return created, nil
	}

	if err := s.Runner.Run(ctx, executil.Command{
		Dir:  taskRootDir,
		Name: "git",
		Args: []string{"symbolic-ref", "HEAD", "refs/heads/" + branchName},
	}); err != nil {
		return created, err
	}

	if err := s.Runner.Run(ctx, executil.Command{
		Dir:  taskRootDir,
		Name: "git",
		Args: []string{
			"-c", "user.name=multi-worktree",
			"-c", "user.email=multi-worktree@local.invalid",
			"commit", "--allow-empty", "-m", "Initialize task root for " + taskName,
		},
	}); err != nil {
		return created, err
	}

	return created, nil
}

func (s *Service) switchBranch(ctx context.Context, dir, branch string, create bool) error {
	switchArgs := []string{"switch"}
	checkoutArgs := []string{"checkout"}
	if create {
		switchArgs = append(switchArgs, "-c", branch)
		checkoutArgs = append(checkoutArgs, "-b", branch)
	} else {
		switchArgs = append(switchArgs, branch)
		checkoutArgs = append(checkoutArgs, branch)
	}

	if err := s.Runner.Run(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: switchArgs,
	}); err == nil {
		return nil
	}

	return s.Runner.Run(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: checkoutArgs,
	})
}

func (s *Service) CurrentBranch(ctx context.Context, dir string) (string, error) {
	output, err := s.Runner.Output(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"branch", "--show-current"},
	})
	return strings.TrimSpace(output), err
}

func (s *Service) CurrentHEAD(ctx context.Context, dir string) (string, error) {
	output, err := s.Runner.Output(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"rev-parse", "HEAD"},
	})
	return strings.TrimSpace(output), err
}

func (s *Service) IsGitRepository(ctx context.Context, dir string) bool {
	return s.Runner.Run(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"rev-parse", "--is-inside-work-tree"},
	}) == nil
}

func (s *Service) StatusPorcelain(ctx context.Context, dir string) (string, error) {
	output, err := s.Runner.Output(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"status", "--porcelain"},
	})
	return strings.TrimSpace(output), err
}

func (s *Service) RecentCommits(ctx context.Context, dir string, limit int) (string, error) {
	output, err := s.Runner.CombinedOutput(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"log", "--oneline", fmt.Sprintf("-%d", limit)},
	})
	return strings.TrimSpace(output), err
}

func (s *Service) CheckoutDetach(ctx context.Context, dir, rev string) error {
	return s.Runner.Run(ctx, executil.Command{
		Dir:  dir,
		Name: "git",
		Args: []string{"checkout", "--detach", rev},
	})
}

func (s *Service) WorktreeRemove(ctx context.Context, repo, worktreePath string) error {
	return s.Runner.Run(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: []string{"worktree", "remove", worktreePath, "--force"},
	})
}

func (s *Service) WorktreePrune(ctx context.Context, repo string) error {
	return s.Runner.Run(ctx, executil.Command{
		Dir:  repo,
		Name: "git",
		Args: []string{"worktree", "prune"},
	})
}

func ForceRemoveDir(path string) error {
	if err := os.RemoveAll(path); err != nil {
		return err
	}
	if _, err := os.Stat(path); err == nil {
		return fs.ErrExist
	}
	return nil
}
