package command

import (
	"errors"
	"fmt"
	"io"
	"strings"

	fuzzyfinder "github.com/ktr0731/go-fuzzyfinder"
)

var ErrCanceled = errors.New("canceled")

type Item struct {
	Label       string
	Description string
}

var fuzzyFind = func(items []Item) (int, error) {
	return fuzzyfinder.Find(
		items,
		func(i int) string {
			if items[i].Description == "" {
				return items[i].Label
			}
			return fmt.Sprintf("%s\t%s", items[i].Label, items[i].Description)
		},
		fuzzyfinder.WithHeader("入力で絞り込み / Enter で決定 / Esc でキャンセル"),
		fuzzyfinder.WithPromptString("dev> "),
		fuzzyfinder.WithPreviewWindow(func(i, width, height int) string {
			if i == -1 {
				return "候補がありません"
			}
			return items[i].Description
		}),
	)
}

func Select(items []Item) (Item, error) {
	if len(items) == 0 {
		return Item{}, fmt.Errorf("候補がありません")
	}

	index, err := fuzzyFind(items)
	if err != nil {
		if errors.Is(err, fuzzyfinder.ErrAbort) {
			return Item{}, ErrCanceled
		}
		return Item{}, fmt.Errorf("候補選択に失敗しました: %w", err)
	}

	if index < 0 || index >= len(items) {
		return Item{}, fmt.Errorf("候補選択の結果が不正です: %d", index)
	}

	return items[index], nil
}

func Confirm(in io.Reader, out io.Writer, prompt string) (bool, error) {
	if _, err := fmt.Fprint(out, prompt); err != nil {
		return false, err
	}

	var answer string
	if _, err := fmt.Fscanln(in, &answer); err != nil {
		if errors.Is(err, io.EOF) {
			return false, nil
		}
		return false, err
	}

	switch strings.ToLower(strings.TrimSpace(answer)) {
	case "y", "yes":
		return true, nil
	default:
		return false, nil
	}
}
