package pathutil

import "testing"

func TestTaskHelpers(t *testing.T) {
	if got := TaskDirName("feat/add-auth"); got != "feat-add-auth" {
		t.Fatalf("TaskDirName() = %q", got)
	}

	if got := TaskRootBranchName("feat/add-auth"); got != "multi-worktree-feat/add-auth" {
		t.Fatalf("TaskRootBranchName() = %q", got)
	}
}
