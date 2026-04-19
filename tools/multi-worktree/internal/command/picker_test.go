package command

import (
	"errors"
	"testing"

	fuzzyfinder "github.com/ktr0731/go-fuzzyfinder"
)

func TestSelect(t *testing.T) {
	original := fuzzyFind
	t.Cleanup(func() {
		fuzzyFind = original
	})

	fuzzyFind = func(items []Item) (int, error) {
		return 1, nil
	}

	selected, err := Select([]Item{
		{Label: "claude1", Description: "claude --dangerously-skip-permissions"},
		{Label: "codex", Description: "codex --yolo"},
	})
	if err != nil {
		t.Fatalf("Select returned error: %v", err)
	}
	if selected.Label != "codex" {
		t.Fatalf("unexpected label: %s", selected.Label)
	}
	if selected.Description != "codex --yolo" {
		t.Fatalf("unexpected description: %s", selected.Description)
	}
}

func TestSelectCanceled(t *testing.T) {
	original := fuzzyFind
	t.Cleanup(func() {
		fuzzyFind = original
	})

	fuzzyFind = func(items []Item) (int, error) {
		return -1, fuzzyfinder.ErrAbort
	}

	_, err := Select([]Item{{Label: "codex", Description: "codex --yolo"}})
	if !errors.Is(err, ErrCanceled) {
		t.Fatalf("expected ErrCanceled, got %v", err)
	}
}

func TestSelectRejectsInvalidIndex(t *testing.T) {
	original := fuzzyFind
	t.Cleanup(func() {
		fuzzyFind = original
	})

	fuzzyFind = func(items []Item) (int, error) {
		return 2, nil
	}

	_, err := Select([]Item{{Label: "codex", Description: "codex --yolo"}})
	if err == nil {
		t.Fatal("expected error for invalid index")
	}
}
