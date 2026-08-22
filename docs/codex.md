# Codexをdevcontainerで使う

AIエージェントはdevcontainer内で実行します。ホストへCodexのための強い権限設定を追加せず、コンテナの隔離環境から
git commit / push、PR作成、その後のCI・レビュー対応を行います。

## 初期設定

ホストでdotfilesを反映し、GitHub CLIへログインしてからdevcontainerを作り直します。

```bash
chezmoi apply
gh auth login --git-protocol https --scopes repo,workflow
gh auth status
mise run apm:install
mise run rulesync:generate
devcontainer up --workspace-folder . --config "$HOME/.config/devcontainer/devcontainer.json"
```

共通devcontainer定義は、ホストの`~/.config/gh`をread-onlyでマウントし、起動時の`GH_TOKEN`もコンテナへ渡します。
また、post-create scriptがGitHub HTTPS用のcredential helperとして`gh auth git-credential`を設定し、ホストの
SSH形式remoteもコンテナ内ではHTTPSへ変換します。このため、GitHub用の秘密鍵やtokenをrepositoryへ追加する必要はありません。

コンテナへ入った後に認証とremoteを確認します。

```bash
gh auth status
git remote -v
git fetch origin
git push --dry-run origin HEAD
```

`GH_TOKEN`を反映するには、`devcontainer up`を実行するホストshellで利用可能にしてください。たとえば、ログイン済みの
GitHub CLIから一時的に渡す場合は次のように起動します。token自体を設定ファイルへ保存しないでください。

```bash
GH_TOKEN="$(gh auth token)" devcontainer up \
  --workspace-folder . \
  --config "$HOME/.config/devcontainer/devcontainer.json"
```

## PR作成後の自律loop

外部skillとしてOpenAIの`gh-address-comments`と`gh-fix-ci`をAPMで導入し、自作の`pr-review-loop` skillが両者をまとめます。
PRを作成すると共通ruleにより自動でloopを開始します。明示的に起動する場合はdevcontainer内のCodexへ次のように依頼します。

```text
$pr-review-loop を使って、このPRのCIとレビュー指摘がなくなるまで対応してください。
```

loopはActions、PR conversation、review summary、inline review threadを監視し、修正、test、commit、同じbranchの`origin`への
push、返信を繰り返します。必須checkが完了し、対応可能な未解決指摘がない状態を2回連続で確認すると終了します。

Codexのsession自体が終了するとポーリングも終了します。常時稼働やsessionをまたぐ監視が必要なら、GitHub Actionsなどの
schedulerから同じskillを定期実行してください。認証切れ、外部CI障害、仕様判断が必要な矛盾した指摘は、安全に自動解決
できないため停止条件です。
