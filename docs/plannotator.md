# Plannotator / Effective HTML

devcontainerでPlannotatorのannotation UIとEffective HTML skillsを使うための設定です。

## 導入

devcontainerの初回作成時に`post-create.sh`が固定版のPlannotatorを検証して導入します。

- Plannotator CLI
- Codex / Claude Code用のreview・annotate skillsとagent連携

Effective HTMLの6 skills（HTML、wireframe、prototype、plan、diagram、design artifact）は
`dot_apm/apm.yml`でupstream commitに固定し、通常の`mise run apm:install`で配布します。

既存containerに反映する場合はrebuildするか、次を実行します。

```bash
bash ~/.config/devcontainer/scripts/post-create.sh
mise run apm:install
```

## HTMLを作成してreviewする

Codexでは`$html`、`$html-wireframe`、`$html-prototype`などを指定して、
self-containedなHTML artifactを作成します。作成後は次のcommandでrenderしたHTMLを
Plannotatorで開き、要素を直接指してfeedbackできます。

```bash
plannotator annotate path/to/artifact.html --render-html
```

Codexへfeedbackを戻す連続的なworkflowでは次の形も使えます。

```text
!plannotator annotate path/to/artifact.html --render-html
```

local diffのcode reviewは`!plannotator review`、agentの最後の返答のannotationは
`!plannotator last`で開きます。

## devcontainerからbrowserを開く仕組み

Plannotatorはcontainer内の`19432`portで待ち受けます。Dockerはこれをhostの
loopbackにだけ公開し、host portは複数containerで衝突しないよう自動採番します。
`post-start.sh`は採番されたportを`~/.plannotator-host-port`へ記録します。

review起動時は`plannotator-browser`がcontainer URLをhost URLへ変換し、SSH経由で
macOSのbrowserを開きます。host portが未取得の場合は`post-start.sh`を再実行してください。
変換後のURLの自動openに失敗した場合は、terminalに表示されるURLをhostのbrowserで開きます。
