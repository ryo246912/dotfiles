# difit

[difit](https://github.com/yoshiko-pg/difit) は、ローカルの Git diff を GitHub 風の browser UI で確認し、
review comment を AI agent へ直接返せる CLI ツールです。この構成では AI agent を devcontainer 内で
実行し、`difit` skill から foreground server を起動して human review を待つ使い方を想定しています。

## 結論: clipboard を介さない review loop

現在の difit は、server 終了時に browser で入力された review comment を標準出力へ返します。
upstream の `difit` skill はその process を foreground で待ち、comment が返った場合は agent に作業を
継続して指摘へ対応するよう指示します。そのため「Copy Prompt」で clipboard へコピーして agent に
貼り付ける操作は不要です。

1. agent が変更を終えたら `difit .` を起動する
2. agent は foreground process の終了を待つ
3. user が host browser の diff へ comment を追加し、review を終了する
4. difit が file / line と comment を標準出力へ返す
5. agent がその出力を読み、修正して次の review round を起動する

browser の「Copy Prompt」は手動連携用として残りますが、この loop では使用しません。crit の
「Send to agent」のように別 agent process を起動する方式ではなく、**difit を起動した同じ agent turn が
CLI の出力を受け取って再開する**方式です。

## 構成

| 項目         | 設定                                                       | 場所                                                       |
| ------------ | ---------------------------------------------------------- | ---------------------------------------------------------- |
| CLI          | `npm:difit@5.0.11` を mise で導入                          | `dot_config/devcontainer/mise.toml`                        |
| skills       | upstream の `difit` / `difit-review` を release tag に pin | `dot_apm/apm.yml`                                          |
| bind / port  | wrapper が `--host 0.0.0.0 --port 4966 --no-open` を追加   | `dot_config/devcontainer/scripts/executable_difit`         |
| port publish | `127.0.0.1::4966`（host port は Docker が自動採番）        | `dot_config/devcontainer/devcontainer.json`                |
| host URL     | `~/.difit-host-port` の実 port を wrapper が表示           | `dot_config/devcontainer/scripts/executable_post-start.sh` |

## インストール

```bash
chezmoi apply
mise run apm:install
```

適用後に devcontainer を rebuild してください。skills は Claude Code の `~/.claude/skills/` と、Codex・
GitHub Copilot・Cursor が利用する `~/.agents/skills/` へ user scope で配置されます。

## 使い方

agent に review を依頼します。

```text
/difit を使って、現在の未コミット変更をレビューできるようにしてください。
```

```text
$difit を使って、現在の未コミット変更をレビューできるようにしてください。
```

agent が表示する `difit UI (host): http://localhost:<自動採番port>` を browser で開いて comment を
追加します。review を終了すると comment が agent に返り、agent はそれを基に修正を続けます。
未追跡ファイルも対象にする場合は `difit . --include-untracked` を使います。

`difit-review` は逆方向の用途で、agent 自身が diff / PR を review し、検出事項を `--comment` で
あらかじめ UI に載せて user へ提示します。

## 注意点

- `--background` を付けると agent が process の終了と comment 出力を待てないため、この review loop では使いません。
- browser を閉じるだけで comment がない場合、agent は「指摘なし」として終了します。
- devcontainer を複数起動しても衝突しないよう、host port は固定していません。
- comment に秘密情報を含めないでください。CLI 出力は agent の context に入ります。
