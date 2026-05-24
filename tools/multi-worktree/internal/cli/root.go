package cli

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/spf13/cobra"

	"github.com/ryo/dotfiles/tools/multi-worktree/internal/app"
	"github.com/ryo/dotfiles/tools/multi-worktree/internal/config"
)

func NewRootCommand(stdin io.Reader, stdout, stderr io.Writer) *cobra.Command {
	application := app.New(config.DefaultPath(), stdin, stdout, stderr)

	rootCmd := &cobra.Command{
		Use:           "multi-worktree",
		Short:         "マルチリポジトリ × git worktree 管理ツール",
		SilenceUsage:  true,
		SilenceErrors: true,
		Long: "複数のリポジトリに対して、タスク単位で git worktree を一括作成・管理します。\n" +
			"Go 実装は source-only な `tools/multi-worktree/` に配置し、wrapper から参照します。",
		Example: strings.Join([]string{
			"  multi-worktree create feat/add-auth",
			"  multi-worktree create feat/add-auth --branch=develop",
			"  multi-worktree recreate feat/add-auth",
			"  multi-worktree list",
			"  multi-worktree status feat/add-auth",
			"  multi-worktree status main --group=work",
			"  multi-worktree sync feat/add-auth --all repo-a repo-b",
			"  multi-worktree exec feat/add-auth repo-a -- make build",
			"  multi-worktree exec main --group=work repo-a -- npm install",
			"  multi-worktree dev feat/add-auth",
			"  multi-worktree open feat/add-auth",
			"  multi-worktree remove feat/add-auth --force",
		}, "\n"),
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	rootCmd.SetIn(stdin)
	rootCmd.SetOut(stdout)
	rootCmd.SetErr(stderr)

	rootCmd.AddCommand(
		newCreateCommand(application),
		newRecreateCommand(application),
		newListCommand(application),
		newStatusCommand(application),
		newSyncCommand(application),
		newCDCommand(application),
		newDevCommand(application),
		newExecCommand(application),
		newOpenCommand(application),
		newRemoveCommand(application),
	)

	return rootCmd
}

func newCreateCommand(application *app.App) *cobra.Command {
	var group string
	var fromBranch string
	var defaultBranch bool

	cmd := &cobra.Command{
		Use:   "create <task-name>",
		Short: "マルチrepoのworktreeを一括作成",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Create(cmd.Context(), app.CreateOptions{
				TaskName:      args[0],
				Group:         group,
				FromBranch:    fromBranch,
				DefaultBranch: defaultBranch,
			})
		},
	}

	cmd.Flags().StringVar(&group, "group", "", "使用するリポジトリグループ")
	cmd.Flags().StringVar(&fromBranch, "from", "", "ベースにするブランチ名")
	cmd.Flags().StringVar(&fromBranch, "branch", "", "ベースにするブランチ名（--from の alias）")
	cmd.Flags().BoolVar(&defaultBranch, "default-branch", false, "各リポジトリのデフォルトブランチを使う")
	cmd.RegisterFlagCompletionFunc("group", groupCompletion(application))
	return cmd
}

func newRecreateCommand(application *app.App) *cobra.Command {
	var group string
	var fromBranch string
	var defaultBranch bool

	cmd := &cobra.Command{
		Use:   "recreate <task-name>",
		Short: "不足しているworktreeを補充し、task設定を再生成",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Recreate(cmd.Context(), app.RecreateOptions{
				TaskName:      args[0],
				Group:         group,
				FromBranch:    fromBranch,
				DefaultBranch: defaultBranch,
			})
		},
		ValidArgsFunction: taskCompletion(application),
	}

	cmd.Flags().StringVar(&group, "group", "", "使用するリポジトリグループ")
	cmd.Flags().StringVar(&fromBranch, "from", "", "ベースにするブランチ名")
	cmd.Flags().StringVar(&fromBranch, "branch", "", "ベースにするブランチ名（--from の alias）")
	cmd.Flags().BoolVar(&defaultBranch, "default-branch", false, "各リポジトリのデフォルトブランチを使う")
	cmd.RegisterFlagCompletionFunc("group", groupCompletion(application))
	return cmd
}

func newListCommand(application *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "タスク一覧表示",
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.List(cmd.Context())
		},
	}
}

func newStatusCommand(application *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "status",
		Short: "各repoの状態確認",
	}

	var group string
	statusMainCmd := &cobra.Command{
		Use:   "main",
		Short: "各repoのデフォルトブランチ（メインworktree）の状態確認",
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.StatusMain(cmd.Context(), group)
		},
	}
	statusMainCmd.Flags().StringVar(&group, "group", "", "使用するリポジトリグループ")
	statusMainCmd.RegisterFlagCompletionFunc("group", groupCompletion(application))

	cmd.AddCommand(statusMainCmd)
	cmd.Args = cobra.ArbitraryArgs
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		if len(args) != 1 {
			return fmt.Errorf("タスク名を指定してください")
		}
		return application.Status(cmd.Context(), args[0])
	}
	cmd.ValidArgsFunction = taskCompletion(application)
	return cmd
}

func newSyncCommand(application *app.App) *cobra.Command {
	var useAll bool
	cmd := &cobra.Command{
		Use:               "sync <task-name> [repo...]",
		Short:             "worktreeの内容をメインworktreeに同期",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: syncCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Sync(cmd.Context(), args[0], useAll, args[1:])
		},
	}
	cmd.Flags().BoolVar(&useAll, "all", false, "rsync で完全同期する")
	return cmd
}

func newCDCommand(application *app.App) *cobra.Command {
	return &cobra.Command{
		Use:               "cd <task-name> [repo]",
		Short:             "worktreeディレクトリに移動",
		Args:              cobra.RangeArgs(1, 2),
		ValidArgsFunction: repoCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			repo := ""
			if len(args) > 1 {
				repo = args[1]
			}
			return application.CD(cmd.Context(), args[0], repo)
		},
	}
}

func newDevCommand(application *app.App) *cobra.Command {
	return &cobra.Command{
		Use:               "dev <task-name> [command...]",
		Short:             "devcontainerでコマンド実行",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: taskCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Dev(cmd.Context(), args[0], args[1:])
		},
	}
}

func newExecCommand(application *app.App) *cobra.Command {
	execCmd := &cobra.Command{
		Use:               "exec <task-name> [<repo>] [--] <command...>",
		Short:             "worktreeの指定リポジトリディレクトリでコマンド実行",
		Args:              cobra.MinimumNArgs(2),
		ValidArgsFunction: repoCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Exec(cmd.Context(), args[0], args[1:])
		},
	}

	var group string
	execMainCmd := &cobra.Command{
		Use:               "main <repo> [--] <command...>",
		Short:             "メインworktreeの指定リポジトリディレクトリでコマンド実行",
		Args:              cobra.MinimumNArgs(2),
		ValidArgsFunction: repoMainCompletion(application, &group),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.ExecMain(cmd.Context(), group, args[0], args[1:])
		},
	}
	execMainCmd.Flags().StringVar(&group, "group", "", "使用するリポジトリグループ")
	execMainCmd.RegisterFlagCompletionFunc("group", groupCompletion(application))

	execCmd.AddCommand(execMainCmd)
	return execCmd
}

func newOpenCommand(application *app.App) *cobra.Command {
	return &cobra.Command{
		Use:               "open <task-name>",
		Short:             "VSCodeでworktreeを開く",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: taskCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Open(cmd.Context(), args[0])
		},
	}
}

func newRemoveCommand(application *app.App) *cobra.Command {
	var force bool
	cmd := &cobra.Command{
		Use:               "remove <task-name>",
		Short:             "worktreeを一括削除",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: taskCompletion(application),
		RunE: func(cmd *cobra.Command, args []string) error {
			return application.Remove(cmd.Context(), args[0], force)
		},
	}
	cmd.Flags().BoolVar(&force, "force", false, "削除失敗時に強制削除を試行する")
	return cmd
}

func taskCompletion(application *app.App) cobra.CompletionFunc {
	return func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		tasks, err := application.ResolveTaskNames(context.Background())
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return filterPrefix(tasks, toComplete), cobra.ShellCompDirectiveNoFileComp
	}
}

func repoCompletion(application *app.App) cobra.CompletionFunc {
	return func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) == 0 {
			return taskCompletion(application)(cmd, args, toComplete)
		}
		repos, err := application.ResolveRepoNamesForTask(context.Background(), args[0])
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return filterPrefix(repos, toComplete), cobra.ShellCompDirectiveNoFileComp
	}
}

func syncCompletion(application *app.App) cobra.CompletionFunc {
	return func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) == 0 {
			return taskCompletion(application)(cmd, args, toComplete)
		}
		repos, err := application.ResolveRepoNamesForTask(context.Background(), args[0])
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return append(filterPrefix([]string{"--all"}, toComplete), filterPrefix(repos, toComplete)...), cobra.ShellCompDirectiveNoFileComp
	}
}

func repoMainCompletion(application *app.App, group *string) cobra.CompletionFunc {
	return func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		repos, err := application.ResolveRepoNamesForGroup(context.Background(), *group)
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return filterPrefix(repos, toComplete), cobra.ShellCompDirectiveNoFileComp
	}
}

func groupCompletion(application *app.App) cobra.CompletionFunc {
	return func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		cfg, err := config.Load(application.ConfigPath)
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return filterPrefix(cfg.GroupNames(), toComplete), cobra.ShellCompDirectiveNoFileComp
	}
}

func filterPrefix(items []string, prefix string) []string {
	filtered := make([]string, 0, len(items))
	for _, item := range items {
		if strings.HasPrefix(item, prefix) {
			filtered = append(filtered, item)
		}
	}
	return filtered
}
