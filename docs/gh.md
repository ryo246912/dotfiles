# GitHub CLI / gh skill メモ

## 方針

`gh skill` は GitHub CLI 組み込みの agent skill 管理コマンドです。この dotfiles では、短期の試用は
`gh skill`、常時使う外部 skill は APM で管理する方針にします。

`gh:skill-install-all` は GitHub Copilot / Cursor / Codex / Claude Code に user scope でまとめて install する
mise task です。skill を省略した場合は一時 directory への install で対話選択を 1 回だけ行い、選択結果を各 agent
へ配布します（`gh skill install` の `--agent` は単一値のため、実際の配布処理は agent ごとに実行します）。

```bash
mise run gh:skill-install-all github/awesome-copilot git-commit
mise run gh:skill-install-all github/awesome-copilot git-commit --pin v2.0.0
```

`--pin` 未指定時は、latest を浮かせたままにしないため、最新 release tag を解決して `gh skill install --pin <tag>`
に渡します。release が無い repository は default branch HEAD SHA に pin します。

## gh skill と APM の使い分け

基本方針は **試し使いは gh skill、常時使用したいものは APM 管理へ昇格**です。

| 観点                   | gh skill                                                                            | APM                                                               |
| ---------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| 主目的                 | skill 単体の検索・preview・install                                                  | 標準セットを manifest で再現可能にする                            |
| この repo での位置付け | 個人の試用導線                                                                      | 常時使用する外部 skill の正式管理                                 |
| 管理単位               | `gh skill install` で agent ごとに配置                                              | `dot_apm/apm.yml` の `dependencies.apm` に宣言                    |
| 再現性                 | `--pin <tag-or-sha>` で個別に固定                                                   | commit SHA と lock file で管理しやすい                            |
| 運用                   | `gh skill preview` / `gh skill search` / `mise run gh:skill-install-all` で軽く試す | `dot_apm/apm.yml` に SHA pin 付きで追加し、`mise run apm:install` |

### 昇格フロー

1. `gh skill search <keyword>` で候補を探す。
2. `gh skill preview <owner>/<repo> [skill]` で内容を読む。
3. `mise run gh:skill-install-all <owner>/<repo> [skill]` で user scope に pin install して試す。
4. 常時使いたいと判断したら、`dot_apm/apm.yml` の `dependencies.apm` に upstream 依存として追加する。
5. `git ls-remote https://github.com/<owner>/<repo> HEAD` などで immutable な commit SHA に pin する。
6. `mise run apm:install` で APM 管理の標準セットとして再配布する。

## 注意

- `gh skill preview` は人間が読むための確認であり、不可視 Unicode などの自動検査までは代替しません。
- `mise run gh:skill-install-all` は user scope の試用導線なので、repo に長期保持したい skill は APM へ移してください。
- APM 側の詳しい manifest / pin / lock 方針は [`docs/apm.md`](./apm.md) を参照してください。
