# Codexをホストで使う

devcontainerを使わず、ホスト上のCodexからgit commit / push、PR作成、その後のCI・レビュー対応まで行うための設定です。

## 初期設定

```bash
chezmoi apply
gh auth login --git-protocol ssh --scopes repo,workflow
gh auth status
mise run apm:install
mise run rulesync:generate
```

gitのuser、GPG署名、GitHubへのpush URLは`~/.config/git/config`から読み込まれます。`gh auth login`はGitHub APIを使う
PR・review操作用で、git pushは既存設定によりSSHを使用します。秘密鍵やGitHub tokenをdotfilesへ追加しないでください。

## Codexの権限

`dot_codex/config.toml`は`approval_policy = "never"`と`sandbox_mode = "danger-full-access"`を設定します。これにより、
ホスト上でもCodexが確認待ちで停止せず、git、gh、test commandを実行できます。一方でfilesystemとnetworkへの制限が弱くなるため、
信頼できるrepositoryとpromptだけで使用してください。未知のrepositoryでは一時的により制限の強いsandboxへ切り替えます。

## PR作成後の自律loop

外部skillとしてOpenAIの`gh-address-comments`と`gh-fix-ci`をAPMで導入し、自作の`pr-review-loop` skillが両者をまとめます。
PRを作成すると共通ruleにより自動でloopを開始します。明示的に起動する場合は次のように依頼します。

```text
$pr-review-loop を使って、このPRのCIとレビュー指摘がなくなるまで対応してください。
```

loopはActions、PR conversation、review summary、inline review threadを監視し、修正、test、commit、同じbranchへのpush、返信を
繰り返します。必須checkが完了し、対応可能な未解決指摘がない状態を2回連続で確認すると終了します。

Codexのsession自体が終了するとポーリングも終了します。常時稼働やsessionをまたぐ監視が必要なら、CodexのAutomationまたは
GitHub Actionsなどのschedulerから同じskillを定期実行してください。認証切れ、外部CI障害、仕様判断が必要な矛盾した指摘は、
安全に自動解決できないため停止条件です。
