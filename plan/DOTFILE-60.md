# DOTFILE-60: wtpの導入

## 目的・スコープ

`gwq`（d-kuro/gwq）から`wtp`（satococoa/wtp）へ移行する。

**背景:**
- gwqにはリモートブランチからworktreeを直接作成する機能がない
- wtpはリモートブランチからのworktree作成に対応（`wtp add <remote-branch>` で可能）
- wtpはworktreeとブランチの同時削除（`--with-branch`）など機能も充実

## 実装方針

gwqをすべて削除し、wtpに置き換える。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `dot_config/mise/config.toml` | `"github:d-kuro/gwq" = "0.0.17"` → `"ubi:satococoa/wtp" = "2.10.3"` |
| `dot_config/zabrze/git-worktree.toml` | gwqのabbreviationをすべてwtp対応に更新 |
| `dot_config/zsh/lazy/mise.zsh` | gwq completion → `eval "$(wtp shell-init zsh)"` |
| `dot_config/gwq/config.toml` | 削除（wtpはプロジェクト単位の`.wtp.yml`で設定） |

## abbreviation変更詳細

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

## 検証方法

- `mise install` でwtpがインストールできること
- `wtp shell-init zsh` がエラーなく動作すること
- `wtp add <branch>` でリモートブランチからworktree作成が可能なこと

## リスクと注意事項

- `wtp`はプロジェクト単位で`.wtp.yml`を用意するスタイルのため、gwqのグローバルbasedir設定（`../worktrees`）は失われる。各プロジェクトで必要に応じて`.wtp.yml`を作成すること
- `gwq add -i -b`の`-i`（インタラクティブ）相当のUIはwtpにはないため、ブランチ名を直接指定するスタイルに変わる
