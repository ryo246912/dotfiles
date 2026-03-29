# DOTFILE-60: wtp と worktrunk の導入

## 目的・スコープ

`gwq`（d-kuro/gwq）から`wtp`（satococoa/wtp）へ移行しつつ、追加要望として`worktrunk`（max-sixty/worktrunk）の設定も導入する。

**背景:**
- gwqにはリモートブランチからworktreeを直接作成する機能がない
- wtpはリモートブランチからのworktree作成に対応（`wtp add <remote-branch>` で可能）
- wtpはworktreeとブランチの同時削除（`--with-branch`）など機能も充実
- worktrunkはshell統合と対話的な`wt switch`を持ち、既存の`../worktrees`運用に寄せた user config を置ける

## 実装方針

- gwqは完全に削除し、既存の`gw*`系操作は`wtp`へ置き換える
- `worktrunk`は追加オプションとして導入し、`gwt*`プレフィックスで独立したショートカットを提供する
- worktree の配置先は、従来の`../worktrees/<repo>-<branch>`を`worktrunk`でも維持する

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `dot_config/mise/config.toml` | `"github:d-kuro/gwq" = "0.0.17"` → `"ubi:satococoa/wtp" = "2.10.3"` |
| `dot_config/mise/config.toml` | `cargo:worktrunk = "0.33.0"` を追加 |
| `dot_config/zabrze/git-worktree.toml` | gwqのabbreviationをwtp対応へ更新し、`gwt*` の worktrunk snippets を追加 |
| `dot_config/zsh/lazy/mise.zsh` | `wtp shell-init zsh` に加えて `wt config shell init` を読み込む |
| `dot_config/worktrunk/config.toml` | `worktree-path` を `../worktrees/{{ repo }}-{{ branch | sanitize }}` に設定 |
| `dot_config/gwq/config.toml` | 削除（wtpはプロジェクト単位の`.wtp.yml`で設定） |

## abbreviation変更詳細

### wtp / gtr 側

| trigger | 旧 | 新 |
|---|---|---|
| `gw` | `gwq` | `wtp` |
| `gwa` | `gwq add -i -b` | `wtp add` |
| `gwab` | (なし) | `wtp add -b`（新規追加） |
| `gwc` | `gwq cd` | `wtp cd` |
| `gwd` | `gwq remove` | `wtp remove` |
| `gwdb` | (なし) | `wtp remove --with-branch`（新規追加） |
| `gwe` | `gwq exec 👇 --` | `wtp exec 👇 --` |
| `gwl` | `gwq list` | `wtp list` |
| `gweh`/`gwem` | `gwq exec HEAD --` | 削除（wtp非対応） |

### worktrunk 側

| trigger | 追加後 |
|---|---|
| `gwt` | `wt` |
| `gwts` | `wt switch` |
| `gwtsc` | `wt switch --create` |
| `gwti` | `wt switch`（picker を開く） |
| `gwtl` | `wt list` |
| `gwtr` | `wt remove` |
| `gwtm` | `wt merge` |

## 検証方法

- `mise install` でwtpがインストールできること
- `mise ls-remote cargo:worktrunk` で `0.33.0` が解決できること
- `wtp shell-init zsh` がエラーなく動作すること
- `wt config shell init` を zsh 側で読み込める構成になっていること
- `wtp add <branch>` でリモートブランチからworktree作成が可能なこと
- `dot_config/worktrunk/config.toml` が既存の `../worktrees` 配置規約を維持していること

## リスクと注意事項

- `wtp`はプロジェクト単位で`.wtp.yml`を用意するスタイルのため、gwqのグローバルbasedir設定（`../worktrees`）は失われる。各プロジェクトで必要に応じて`.wtp.yml`を作成すること
- `gwq add -i -b`の`-i`（インタラクティブ）相当のUIはwtpにはないため、ブランチ名を直接指定するスタイルに変わる
- `worktrunk` の shell integration は upstream が `wt config shell install` を推奨しているため、repo 側では `wt config shell init` を評価する保守的な組み込みにする
- sandbox 制約により `.git` への書き込みを伴う `git fetch` / `git commit` / `git push` が失敗する可能性があるため、Linear の Notes に実行結果を残す
