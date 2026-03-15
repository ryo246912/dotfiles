# DOTFILE-30 ブラウザ操作 CLI の設定

## 概要

- AI agent がブラウザ状態を確認できるように、repo 管理の browser CLI / helper / 手順書を整備します。
- 主対象は devcontainer から macOS host 上の Chrome remote debugging endpoint を扱う導線です。
- 主目的は devcontainer 内の agent が host Chrome の複数 slot を再現的に読めるようにすることで、wrapper script はそのための薄い補助として扱います。
- 今回の scope は CLI / host bridge / Gherkin skill に限定し、MCP 登録や `claude mcp` 設定は対象外とします。

## 要件

### 機能要件

- 最大 3 つの browser slot を単一 source で管理し、`port`、`browserUrl`、`userDataDir` を切り替えられること。
- devcontainer 内の agent が、thin CLI もしくは repo 管理の手順に従って host Chrome を slot 単位で起動・状態確認できること。
- Playwright ベースの repo CLI から、選択した slot に接続して page を開く、状態確認する、benign な 1 操作を実行できること。
- host / devcontainer のどちらから操作する場合でも参照できる browser operation shared skill を rulesync source に追加できること。
- 成功した操作手順を、他 agent でも再利用しやすい Gherkin shared skill として rulesync source に追加できること。

### 非機能要件

- slot 定義は tracked source 1 箇所に集約し、host 操作と Playwright 操作が同じ定義を参照すること。
- CLI-first を維持し、Desktop 向け設定や MCP 設定に依存しないこと。
- Gherkin skill は座標操作や不安定な DOM 順序に依存せず、role / text / stable selector 優先で記述すること。
- wrapper script を置く場合でも責務は薄く保ち、既存 dotfiles 導線を壊さず再実行可能であること。

### 制約条件

- このセッションでは repo 外のファイル編集は行えないため、source / script / docs は repo 配下に閉じる必要があります。
- sandbox 制約により `git fetch origin main` は `FETCH_HEAD` 更新に失敗するため、pull 相当の記録は local ref ベースになります。
- 現在の実行環境では `host.docker.internal` を解決できず、host Chrome の疎通確認は devcontainer 側での検証を前提にします。
- 明示承認前は実装を開始せず、plan artifact と Linear workpad の更新までに留めます。

## 現状整理

- `playwright` CLI は mise 管理で導入済みで、`playwright --version` は `1.56.0` です。
- `playwright open` / `codegen` / `screenshot` / `run-server` は使えますが、host Chrome の multi-slot endpoint に接続する repo 管理 wrapper はまだありません。
- `dot_config/devcontainer/scripts/executable_post-start.sh` は `mac-host -> host.docker.internal` の SSH alias を生成しており、devcontainer から host command を実行する既存経路として再利用できます。
- `dot_config/navi/cheats/other.cheat.md` の Chrome 起動例は `9222` の単一 profile だけです。
- rulesync の shared skill source は `dot_config/rulesync/.rulesync/skills/` 配下にあります。
- issue コメントでは「コンテナ側で host Chrome の複数ポートに接続して操作する方法を agent が知っていればよく、重い wrapper は必須ではない」と補足されています。
- `dot_local/bin/executable_setup-ai-tool`、`dot_claude/.mcp.json`、`dot_claude/modular-mcp.json` は MCP 文脈のため、この ticket では変更対象から外します。

## 実装計画

### 1. Browser slot 定義を単一 source として追加する

- 新規 `dot_config/browser-cli/slots.json` を追加し、`slot1` から `slot3` の定義を集約します。
- 形式は shell と `jq` で扱いやすい JSON にし、`id`、`displayName`、`port`、`browserUrl`、`userDataDir`、`hostAlias`、`notes` を持たせます。
- 初期値は `9222`、`9223`、`9224` を使い、devcontainer から見える `http://host.docker.internal:<port>` を `browserUrl` に保持します。

実装イメージ:

```json
{
  "slots": [
    {
      "id": "slot1",
      "displayName": "Chrome Slot 1",
      "port": 9222,
      "browserUrl": "http://host.docker.internal:9222",
      "userDataDir": "$HOME/chrome-profiles/slot1",
      "hostAlias": "mac-host",
      "notes": "default validation slot"
    }
  ]
}
```

### 2. Host Chrome 管理用の thin CLI / command entrypoint を整える

- 新規 `dot_local/bin/executable_browser-cli` を追加し、`list`、`show <slot>`、`start <slot>`、`host-command start <slot>`、`status [slot]`、`url <slot>`、`json-version <slot>` を扱う薄い entrypoint にします。
- slot 定義は `dot_config/browser-cli/slots.json` を参照し、host 側 Chrome 起動時は `--remote-debugging-port` と `--user-data-dir` を slot から解決します。
- Chrome 実体の差分は `BROWSER_CLI_CHROME_BIN` で override 可能にし、未指定時は macOS の `open -na "Google Chrome"` を優先しつつ fallback を持たせます。
- もし実装時に direct command のほうが明快で壊れにくいと判断できる場合は、wrapper は slot 解決と help 出力だけに留め、実操作は Playwright helper と docs に寄せます。

実装イメージ:

```sh
browser-cli list
browser-cli show slot2
browser-cli host-command start slot2
browser-cli start slot2
browser-cli status slot2
browser-cli url slot2
curl "$(browser-cli url slot2)/json/version"
```

### 3. Playwright 操作用の repo CLI を追加する

- 新規 `dot_local/bin/executable_browser-playwright` を追加し、Playwright から selected slot の `browserUrl` へ接続する CLI entrypoint にします。
- `browser-cli` からこの helper を呼べる形にし、`pages`、`goto <slot> <url>`、`screenshot <slot> <url> <path>`、`click <slot> <url> <selector>` のような最小操作を揃えます。
- 実装は Playwright の CDP 接続を使い、成功した操作を後段の Gherkin 化に流せるよう、slot / URL / selector / expected result をログに残します。

実装イメージ:

```sh
browser-cli pages slot2
browser-cli goto slot2 https://example.com
browser-cli screenshot slot2 https://example.com /tmp/slot2-example.png
browser-cli click slot2 https://example.com 'role=button[name="Settings"]'
```

### 4. Devcontainer から host slot を扱う導線を揃える

- `dot_config/devcontainer/scripts/executable_post-start.sh` の `mac-host` alias を再利用し、新しい接続方式は増やしません。
- `dot_config/devcontainer/devcontainer.json` には必要なら `BROWSER_HOST=host.docker.internal` や `BROWSER_SLOT_DEFAULT=slot1` のような環境変数だけを追加します。
- host 側の Chrome 起動は、devcontainer から `ssh mac-host` で workspace 上の thin CLI もしくは同等の repo 管理 command を呼ぶ前提にします。

実装イメージ:

```sh
# devcontainer 内
ssh mac-host "$(browser-cli host-command start slot3)"
curl http://host.docker.internal:9224/json/version
browser-cli pages slot3
```

### 5. Browser operation / Gherkin shared skills を rulesync source に追加する

- 新規 skill 名は `browser-ops` と `browser-gherkin` を候補とし、`dot_config/rulesync/.rulesync/skills/browser-ops/SKILL.md` と `dot_config/rulesync/.rulesync/skills/browser-gherkin/SKILL.md` を追加します。
- `browser-ops` には host / devcontainer の両方の起動・接続経路、slot 切り替え、Playwright 経由の確認方法、wrapper 不要時の direct command fallback を書きます。
- `browser-gherkin` には「成功した操作だけを対象にする」「slot / 開始 URL / 安定 selector / 期待結果を残す」「探索途中の失敗ログはそのまま手順化しない」を必須ルールとして書きます。
- `browser-gherkin` の出力は `Feature` / `Scenario` / `Given` / `When` / `Then` を持つ最小構成に固定し、共有しやすい wording に揃えます。

実装イメージ:

```gherkin
Feature: Browser operation replay

  Scenario: Open settings menu from slot2
    Given browser slot "slot2" is reachable at "http://host.docker.internal:9223"
    And the page "https://example.test/" is open
    When the agent clicks the "Settings" button by role
    Then the settings menu is visible
```

### 6. ドキュメントを CLI-first で追従させる

- `dot_config/navi/cheats/other.cheat.md` に multi-slot Chrome 起動例、`browser-cli`、Playwright CLI helper の利用例を追加します。
- `setup.md` に Browser CLI / host Chrome / devcontainer bridge のセットアップ手順を追記します。
- `dot_config/rulesync/README.md` には shared skill を追加したときの generate / `chezmoi re-add` の注意点だけを必要最小限で追記します。

## 変更対象ファイル

- `plan/DOTFILE-30.md`
- `dot_config/browser-cli/slots.json`
- `dot_local/bin/executable_browser-cli`
- `dot_local/bin/executable_browser-playwright`
- `dot_config/devcontainer/devcontainer.json`
- `dot_config/devcontainer/scripts/executable_post-start.sh`
- `dot_config/navi/cheats/other.cheat.md`
- `setup.md`
- `dot_config/rulesync/.rulesync/skills/browser-ops/SKILL.md`
- `dot_config/rulesync/.rulesync/skills/browser-gherkin/SKILL.md`
- `dot_config/rulesync/README.md`

変更対象外:

- `dot_local/bin/executable_setup-ai-tool`
- `dot_claude/.mcp.json`
- `dot_claude/modular-mcp.json`
- `dot_config/claude/*.json`

## 検証方針

- repo 内静的検証
  - `git status --short --branch`
  - `jq empty dot_config/browser-cli/slots.json`
  - `bash -n dot_local/bin/executable_browser-cli`
  - `node --check dot_local/bin/executable_browser-playwright`
  - `bash -n dot_config/devcontainer/scripts/executable_post-start.sh`
- slot 導通確認
  - `browser-cli list`
  - `browser-cli show slot2`
  - `browser-cli host-command start slot2`
  - `browser-cli url slot2`
  - `curl http://host.docker.internal:9222/json/version`
  - `curl http://host.docker.internal:9223/json/version`
  - `curl http://host.docker.internal:9224/json/version`
- Playwright 操作確認
  - `browser-cli pages slot2`
  - `browser-cli goto slot2 https://example.com`
  - `browser-cli screenshot slot2 https://example.com /tmp/dotfile-30-slot2.png`
  - benign な 1 操作を成功させる
- rulesync source 確認
  - `rg -n "browser-cli|browser-playwright|browser-ops|browser-gherkin" -S dot_config dot_local setup.md`
  - 成功した操作を `browser-gherkin` skill のルールで Gherkin に落とし込む

## リスクと未解決点

- Playwright CLI 自体は既存 host Chrome slot 接続を直接 abstraction していないため、repo 側 helper の責務をどこまで持たせるかを実装時に詰める必要があります。
- thin wrapper と direct command docs のどちらがより壊れにくいかは、実装時の検証結果で最終決定する必要があります。
- host Chrome の実体コマンドは環境差分を持つ可能性があるため、wrapper 側で override を許容する必要があります。
- 現セッションは devcontainer ではなく、`curl http://host.docker.internal:<port>/json/version` が名前解決で失敗しました。実装後の疎通確認は devcontainer で再実行する前提です。
- `rulesync generate` は repo 外へ書き出すため、この ticket の完了条件は source 編集と repo 内検証を基本とし、generate は必要性を見ながら扱います。

## 参考ファイル

- `dot_local/bin/executable_setup-ai-tool`
- `dot_config/devcontainer/devcontainer.json`
- `dot_config/devcontainer/scripts/executable_post-start.sh`
- `dot_config/navi/cheats/other.cheat.md`
- `setup.md`
- `dot_config/rulesync/README.md`
