# crit

[crit](https://github.com/tomasz-tomczyk/crit) は、プラン・diff・フロントエンドをブラウザ上でレビューし、
コメントをそのままエージェントへフィードバックできる CLI ツールです。
**AIエージェントは devcontainer 内で実行する前提**で統合しています（devcontainer 定義は
`dot_config/devcontainer/` を参照）。

## 構成

| 項目         | 設定                                                                      | 場所                                                                                  |
| ------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| バイナリ     | `github:tomasz-tomczyk/crit` を mise で導入                               | `dot_config/devcontainer/mise.toml`                                                   |
| バインド先   | `CRIT_HOST=0.0.0.0` / `CRIT_PORT=7842`（コンテナ内は固定）                | `dot_config/devcontainer/devcontainer.json` (`remoteEnv`)                             |
| 非認証許可   | `CRIT_ALLOW_UNAUTHENTICATED_NETWORK=1`                                    | `dot_config/devcontainer/devcontainer.json` (`remoteEnv`)                             |
| ポート公開   | `appPort: 127.0.0.1::7842` でホストへ publish（host port は自動採番）     | `dot_config/devcontainer/devcontainer.json`                                           |
| 自動起動抑止 | `CRIT_NO_UPDATE_CHECK=1`                                                  | `dot_config/devcontainer/devcontainer.json`                                           |
| 動作設定     | `~/.crit.config.json` を生成（`no_open` / `agent_cmd`）                   | `dot_config/devcontainer/scripts/post-create.sh`                                      |
| ポート通知   | 割り当てられた host port を `~/.crit-host-port` に記録し、mac-host へ通知 | `dot_config/devcontainer/scripts/executable_post-start.sh`（適用後: `post-start.sh`） |

`~/.crit.config.json` の内容:

```json
{
  "no_open": true,
  "agent_cmd": "claude --dangerously-skip-permissions -p"
}
```

- `no_open` … コンテナ内にはブラウザが無いため自動オープンを無効化（UIはホスト側で開く）
- `agent_cmd` … コメントの「Send to agent」で、コンテナ内の `claude` に権限スキップで処理を委譲

## 使い方

コンテナ内でエージェント（または自分）が crit を起動します。

```bash
crit            # git の変更を自動検出してレビュー
crit plan.md    # 特定ファイルをレビュー
```

起動すると（コンテナ内は固定の）`http://0.0.0.0:7842` で待ち受けます。`appPort` によりホストへ
publish されますが、host port は **`127.0.0.1::7842` として Docker に自動採番させている**ため、
devcontainer を複数同時に起動してもポート衝突は起きません。実際に割り当てられた host port は
`~/.crit-host-port` に記録されるので、ホストのブラウザではその番号で `http://localhost:<port>` を
開いてレビュー・コメントします。コメントを送るとエージェントへフィードバックされ、修正ループが回ります。

crit は認証機能を持たないため、非 loopback の `CRIT_HOST` を指定すると、明示的な許可がない限り起動を
拒否します。この構成では `CRIT_ALLOW_UNAUTHENTICATED_NETWORK=1` を設定して確認を省略していますが、
Docker がコンテナのポートをホストの `127.0.0.1` にだけ publish するため、LAN やインターネットへは
公開されません。`appPort` を変更する場合は、ホスト側の bind address を `0.0.0.0` にしないでください。

> [!IMPORTANT]
> ポート公開には **`appPort` を使う**。`forwardPorts` は VS Code 拡張専用で、`multi-worktree` の
> `devcontainer up`（devcontainer CLI）では解釈されず publish されない（これが当初ホストから
> 開けなかった原因）。

## ポートの自動採番と通知

以前は host port を `7842` に固定していたため、devcontainer を同時に2つ以上起動すると
`Bind for 127.0.0.1:7842 failed: port is already allocated` で衝突していた。これを避けるため、
`appPort` の host 側は指定せず(`127.0.0.1::7842`)、Docker に自動採番させている
（`postCreateCommand` / `postStartCommand` が実行される**前**に Docker がポートを確定するため、
コンテナ内のスクリプトから host port 自体を選ぶことはできない）。

自動採番なので、実際に割り当てられた host port はコンテナの外（ホスト側）からしか分からない。
そこで `post-start.sh` が起動のたびに次を行う。

1. コンテナの `$HOSTNAME`（Docker のデフォルトで short container ID と一致）を使い、
   `mac-host` へ SSH して `docker port "$HOSTNAME" 7842/tcp` を実行し、割り当てられた host port を取得
2. 取得できたら `~/.crit-host-port` に書き込む
3. `macos-notify-cli` でホストへ `crit UI: http://localhost:<port>` を通知する

`multi-worktree` に限らず、この base template (`dot_config/devcontainer/devcontainer.json`) から
起動する devcontainer であればどの経路（devcontainer CLI 直接、VS Code など）でも同じ仕組みが働く。
devcontainer 外（`mac-host` に SSH できない環境）では静かにスキップされる。

ホストのブラウザで実際に開ける URL の relay は、`crit` ラッパー（後述）が `~/.crit-host-port` を
読んで `crit UI (host): http://localhost:<port>` を追加出力することで行う（crit が出力するのは
コンテナ内固定の `7842` であり、ホストから実際に開ける port とは異なるため）。

## `/crit` skill（APM で upstream 依存として配布）

crit@crit プラグインが提供する 2 つの skill を、**APM の外部依存として upstream から取得**しています。
`dot_apm/apm.yml` の `dependencies.apm` に `tomasz-tomczyk/crit/integrations/claude-code/skills/{crit,crit-cli}`
をコミット SHA 付きで宣言しており、`chezmoi apply` → `mise run apm:install`（= `apm install -g`）で各エージェント
向けに配置されます（`docs/apm.md` 参照）。skill 本文はこのリポジトリに vendor せず、pristine な upstream を使います。

| skill      | 役割                                                               | 配布先                       |
| ---------- | ------------------------------------------------------------------ | ---------------------------- |
| `crit`     | レビューループ（起動 → レビュー → 反映）を自動化する `/crit`       | `~/.claude/skills/crit/`     |
| `crit-cli` | `crit comment` / `share` / `pull` / `push` など CLI のリファレンス | `~/.claude/skills/crit-cli/` |

配置された skill は devcontainer の `~/.claude` マウント経由でコンテナ内のエージェントからも利用できます。

> [!NOTE]
> このリポジトリ固有の devcontainer グルー（host port の URL 差し替え・再レビュー通知）は skill 本文には
> 埋め込まず、`crit` ラッパー（次節）へ分離しています。そのため skill は pristine な upstream をそのまま
> 依存として使えます。

## `crit` ラッパー（devcontainer グルー）

- **host URL の relay**: `~/.crit-host-port` があれば `crit UI (host): http://localhost:<port>` を
  crit 本体の出力とは別に 1 行追加する（crit の出力自体は改変しない）。
- **再レビュー待ち通知**: 既に crit daemon が `:7842` で待ち受けている状態でレビューを起動した
  （＝再レビューラウンド）場合に、`mac-host` へ SSH して `macos-notify-cli` で「再レビュー待ちです」を通知。
  `comments` / `share` / `comment` 等のサブコマンド呼び出しでは通知しない。

## GitHub PRとreview commentを同期する

このrepositoryでpinしているcrit v0.18.2では、`crit pull` / `crit push`でGitHub PRとlocal review fileを同期できます。
どちらも内部でGitHub CLI (`gh`)を使います。最初にdevcontainer内で認証状態と対象PRを確認してください。

```bash
gh auth status
gh pr view --json number,url,headRefName,baseRefName
```

`gh auth status`が失敗する場合は`gh auth login`で認証します。現在branchに対応するPRを`gh pr view`で検出できれば、
以降のcommandではPR番号を省略できます。検出できない場合や別PRを扱う場合は、`crit pull 123`のように番号を明示します。

### `pull`: GitHubの指摘をlocal reviewへ取り込む

```bash
crit pull            # current branchからPR番号を自動検出
crit pull 123        # PR #123を明示
```

`pull`はGitHub上のinline review commentをactiveなcrit review fileへmergeします。同じcommentを再度pullしても、
author・line・bodyにより重複を除外します。取り込んだ後に`crit`を起動すると、GitHubの指摘をlocal UIで確認できます。

```bash
crit pull
crit                 # browserでGitHubの指摘を確認し、replyや追加commentを作成
```

AI agentへ任せる場合は、`/crit`または`$crit`を使ってreviewを開始し、取り込んだ未解決commentへの対応を依頼します。
agentが修正した後はround-to-round diffを確認し、必要ならlocal threadへreplyを追加します。

### `push`: local commentをGitHubへ投稿する

`push`はlocal review fileの未解決comment / replyをGitHub PR reviewとして投稿します。誤投稿を避けるため、必ず最初に
`--dry-run`で投稿対象とPR番号を確認します。

```bash
crit push --dry-run          # current branchのPRへ何を投稿するか表示
crit push --dry-run 123      # PR #123を明示
crit push                    # default event: comment
crit push 123                # PR #123へ投稿
```

review全体のmessageを付ける場合は`--message`（短縮形`-m`）、review outcomeを指定する場合は`--event`を使います。

```bash
crit push -m "Round 2の確認結果です"
crit push --event approve -m "指摘への対応を確認しました"
crit push --event request-changes -m "未対応の指摘があります"
```

`--event`は次の3種類です。

| value             | GitHub上の結果                     | message  |
| ----------------- | ---------------------------------- | -------- |
| `comment`         | 通常のPR review comment（default） | 任意     |
| `approve`         | PRをApprove                        | 任意     |
| `request-changes` | Request changes                    | **必須** |

> [!CAUTION]
> `crit push`はremoteへ書き込む操作です。AI agentに実行させる場合も、少なくとも運用開始時は`--dry-run`の結果をuserが
> 確認してから本番の`push`を許可してください。対象PR・file・line・comment bodyが意図どおりかを確認します。

### 推奨するPR review loop

```text
1. PR branchへcheckoutし、`gh pr view`で対象PRを確認
2. `crit pull`でGitHubのreview commentをlocalへimport
3. `/crit`でagentが指摘を読み、修正
4. browserでround-to-round diffを再reviewし、replyまたは追加commentを作成
5. `crit push --dry-run`で投稿内容を確認
6. `crit push`でGitHubへreply / commentを投稿
7. 必要なら再度`crit pull`し、追加のremote feedbackを取り込んで繰り返す
8. 全指摘を確認したら`crit push --event approve -m "..."`（自分のPRを自分でapproveできない点に注意）
```

`pull`と`push`の向きを混同しないよう、**GitHub → localがpull、local → GitHubがpush**と覚えます。`pull`はcodeを
`git pull`するcommandではなく、review commentをcritのlocal review fileへ取り込むcommandです。

### よくある問題

| 症状                      | 確認すること                                                                                   |
| ------------------------- | ---------------------------------------------------------------------------------------------- |
| PRを自動検出できない      | `gh pr view`を実行できるbranchか確認する。難しければPR番号を明示する                           |
| `gh`の認証error           | devcontainer内で`gh auth status`を確認し、必要なら`gh auth login`する                          |
| pull後にcommentが見えない | 対象repository / branch / active review sessionが同じか`crit status`で確認してから`crit`を開く |
| push先や内容が不安        | `crit push --dry-run [PR番号]`を実行し、投稿先とpostable commentを確認する                     |
| `request-changes`が失敗   | `--message`を必ず指定する                                                                      |
| 自分のPRをapproveできない | GitHubの制約。別reviewerにapproveを依頼する                                                    |

複数のcrit reviewがある場合は`crit status`で現在のreview fileを確認します。default以外の保存先を同期する場合は、同じ
`--output <directory>`（短縮形`-o`）をpullとpushの両方へ指定します。たとえば`crit pull -o .crit 123`で取り込んだ後は、
`crit push -o .crit --dry-run 123`で同じreview fileの投稿内容を確認します。`--session`はreview UIへの再接続用であり、
v0.18.2の`pull` / `push` optionではありません。

> [!NOTE]
> upstream v0.18.4ではGitLab MR syncも追加されていますが、このrepositoryは現在v0.18.2へpinしています。GitLab運用を
> 始める場合は、crit本体とAPM skillsを同じreleaseへ更新し、`glab auth status`、`crit pull --forge gitlab`、
> `crit push --forge gitlab --dry-run`を検証してから利用してください。

## difit・crit・Plannotator比較レポート

調査日: 2026-08-11

比較表は調査日時点のupstream release（difit 5.0.11、crit 0.18.4、Plannotator 0.26.8）を対象にしています。
このrepositoryで実際にpinしているcritはv0.18.2のため、version差がある機能は本文で区別します。

### 結論

このrepositoryの主用途には、**critを第一候補として継続利用する**のが最も適しています。

理由は、次の必須・希望条件を3つとも最も直接的に満たすためです。

1. local diffへline / range commentを付けられる
2. review終了後に同じAI agentがfeedbackを読み、修正後の差分を再reviewするloopを公式integrationが提供する
3. GitHub PR / GitLab MRのcommentをpullし、local comment・reply・review outcomeをpushできる

**Plannotatorは第二候補**です。local diff / remote PR・MR、agentへのfeedback返却、platformへのinline review投稿を満たし、
PR discussion、checks、stacked PR、複数VCS、組み込みAI reviewなど、review UIとしては最も高機能です。一方、既存threadへの
reply・同期を中心に運用する場合は、`pull` / `push`を明示するcritの方が機能境界と運用手順が分かりやすいです。

**difitは軽量なdiff viewerが欲しい場合の第三候補**です。local diff reviewとagentへのfeedback返却はできますが、GitHub連携は
PR patchと未解決inline threadのimportまでです。localで付けたcommentをPRへ投稿したり、既存threadへreplyしたりする機能は
確認できませんでした。今回の希望条件ではcrit / Plannotatorより不足があります。

### 評価条件

| 優先度 | 条件                | 判定基準                                                                               |
| ------ | ------------------- | -------------------------------------------------------------------------------------- |
| 必須   | local diff review   | 未commit / staged / branch差分をbrowserで表示し、code lineまたはrangeへcommentできる   |
| 必須   | agent feedback loop | clipboardへの手動copyなしでfeedbackをagentへ返し、修正後に再reviewできる               |
| 希望   | GitHub PR連携       | PRのdiff・既存commentを取得でき、local reviewのcomment・reply・outcomeをGitHubへ返せる |
| 加点   | review支援          | plan / frontend、round間diff、AI review、複数VCS、共有、privacy、container運用など     |

### 比較サマリー

| 項目                     | difit 5.0.11                                     | crit 0.18.4                                    | Plannotator 0.26.8                                                            |
| ------------------------ | ------------------------------------------------ | ---------------------------------------------- | ----------------------------------------------------------------------------- |
| local Git diff           | **○** working / staged / commit / branch / stdin | **○** 自動検出、line / range comment           | **○** uncommitted / staged / unstaged / commit / base branch                  |
| codeへのinline review    | **○** single line / range                        | **○** single line / range                      | **○** selection annotation / suggestion                                       |
| clipboard不要のagent返却 | **○** 終了時stdout + `difit` skill               | **○** `/crit` integrationのreview loop         | **○** 終了時stdout + agent skill / hook                                       |
| 修正後の再review         | **△** 再起動して新しいroundを開く                | **◎** round-to-round diff、通知、file watch    | **○** 再実行可能。planはversion historyあり                                   |
| GitHub PR diff取得       | **○** `--pr`                                     | **○** `crit pr` / remote review                | **○** PR URL、PR切替、Layer / Full stack                                      |
| 既存PR comment取得       | **△** 未解決inline threadのみ                    | **◎** reply / edit / delete / resolutionを同期 | **◎** full discussion / inline thread / checksを取得                          |
| GitHubへreview投稿       | **×** 確認できず                                 | **◎** comment、reply、approve、request changes | **○** inline / general review、approve                                        |
| 既存threadへのreply      | **×** 確認できず                                 | **◎** bidirectional sync                       | **△** 既存discussion取得は可能。既存threadへのreply APIは公式文書で確認できず |
| GitLab MR                | **×** 確認できず                                 | **◎** GitLab.com / self-managed                | **○** MR取得・review投稿                                                      |
| plan / Markdown          | **×** diffとしてのMarkdown表示のみ               | **○** plan / Markdown review                   | **◎** plan hook、文書・agent message annotation                               |
| running Web app review   | **×**                                            | **◎** proxy + DOM element feedback             | **△** HTML artifact review（running app proxyは確認できず）                   |
| 組み込みAI review        | **△** agentが`--comment`を生成                   | **△** agentのprogrammatic comment              | **◎** Ask AI、AI review、Guided Review                                        |
| 対応VCS                  | Git                                              | Git / jj / Sapling、GitHub / GitLab            | Git / jj / GitButler / Perforce、GitHub / GitLab                              |
| team共有                 | **×** 確認できず                                 | **○** share URL / organization / self-host     | **○** encrypted link、Workspaces（OSS link共有はdeprecated方向）              |
| 導入の軽さ               | **◎** npm / npx + skill                          | **○** single binary + integration              | **△** installerがbinary / hook / skillを設定                                  |

記号は、この調査で確認できた公式README・公式document・release sourceに基づく相対評価です。`△`は一部対応または
追加運用が必要、`×`は現行の公式情報で機能を確認できなかったことを表し、「実装が絶対に存在しない」という意味ではありません。

### 1. difit

#### 条件への適合

- `difit .`、`staged`、`working`、commit / branch比較、stdin patchに対応します。
- diffのsingle line / rangeへcommentでき、agent向けskillはforeground processの終了を待ちます。review commentが返れば
  同じconversationで修正を継続できるため、`Copy Prompt`は必須ではありません。
- `difit --pr <URL>`は`gh pr diff --patch`でPR diffを取得し、未解決inline review threadを起動時commentとしてimportします。
- `--comment`によりagent側の指摘や説明をUIへ事前投入できます。

#### 弱点

- GitHub連携は**read / import中心**です。local commentをGitHub reviewとして投稿するCLI、既存threadへのreply、approve / request
  changesは公式READMEとCLI optionから確認できませんでした。
- commentはbrowser localStorageへ保存されます。複数環境・複数reviewerで同期する用途には追加の仕組みが必要です。
- round-to-round専用UIは確認できず、agentが修正後にcommandを再実行してreviewを開き直す運用になります。

#### 向くケース

- installとUIが軽いGitHub風local diff viewerを使いたい
- GitHubへ書き戻す必要がなく、人間からagentへの単純なfeedback loopだけでよい
- 任意のunified diffをstdinでreviewしたい

公式情報: [README](https://github.com/yoshiko-pg/difit/blob/main/README.md)、
[`difit` skill](https://github.com/yoshiko-pg/difit/blob/main/skills/difit/SKILL.md)、
[v5.0.11](https://github.com/yoshiko-pg/difit/releases/tag/v5.0.11)

### 2. crit

#### 条件への適合

- local Git changeを自動検出し、single line / range commentを付けられます。
- 公式integrationの`/crit`は起動、human review待機、feedbackへの対応、再reviewをloopします。
- 修正後はround-to-round diffをsplit / unified viewで確認できます。
- `crit pull`はGitHub PR / GitLab MRのcommentを取得し、reply、edit、delete、discussion resolutionを重複なしで同期します。
- `crit push`はinline comment / replyに加え、summary、approve、request changesをremoteへ投稿できます。`--dry-run`で事前確認も可能です。

#### プラスアルファ

- plan / Markdown、static HTML、running Web applicationを同じCLIでreviewできます。
- running appではcookie fileやChrome DevTools Protocolを使ったsession cookie転送にも対応します。
- agentが`crit comment`でprogrammatic commentを追加できます。
- 実験的な「Send now」はcommentを設定済みagentへ即時送信し、replyをUIへ戻します。file watchによりagentの編集もUIへ反映します。
- async share、organization visibility、self-host可能なshare server、story mode、review round通知があります。
- GitHubだけでなくGitLab.com / self-managed GitLabにも対応します。

#### 注意点

- 「Send now」の`agent_cmd`へ強い権限を与える構成は便利ですが、実行可能範囲とrepositoryの信頼性を確認する必要があります。
- Web app proxyはoriginが変わるため、認証画面ではcookie転送設定が必要になる場合があります。
- 機能が多いため、diff表示だけが目的ならdifitより設定・運用項目は増えます。

#### 向くケース

- 今回の条件を1つのtoolで最も確実に満たしたい
- GitHub / GitLabのreview threadをlocalと双方向同期したい
- codeだけでなくplanやrunning Web appも同じfeedback loopでreviewしたい

公式情報: [README](https://github.com/tomasz-tomczyk/crit/blob/main/README.md)、
[GitHub PR / GitLab MR sync](https://github.com/tomasz-tomczyk/crit/blob/main/README.md#github-pr-and-gitlab-mr-sync)、
[v0.18.4](https://github.com/tomasz-tomczyk/crit/releases/tag/v0.18.4)

### 3. Plannotator

#### 条件への適合

- local Git diffはall changes、uncommitted、staged、unstaged、last commit、base branch比較を切り替えられます。
- diff selectionへcomment、delete、quick label、looks good、code suggestionを付け、`Send Feedback`でagentへ返せます。
- Codexでは`plannotator review`のstdoutをskillが待つ方式です。plan reviewはexperimentalな`Stop` hookからfeedbackを返し、
  version historyと差分を保ったまま同じturnでplanを修正できます。
- GitHub PR / GitLab MRはauthenticated CLIでdiff、metadata、checks、description、full discussion、inline threadを取得します。
- review先をagent sessionとplatformから選べ、GitHub / GitLabへinline / general reviewまたはapproveを投稿できます。

#### プラスアルファ

- PR Overviewでdescription、checks、discussionをまとめて確認し、bot、resolved / outdated、author、textでfilterできます。
- stacked PR / MRをLayerとFull stackで切り替えられます。platformへの投稿は正しくanchorできるLayerだけに制限されます。
- Ask AI、複数agentによるAI review、変更を章立てするGuided ReviewをUI内から実行できます。
- Git、GitButler、jj、Perforceを扱えます。Git status / Tree / Commits view、stage / unstage、base fetchも備えます。
- plan、spec、Markdown、agentのlast message、HTML artifact、URLをannotationできます。
- local dataはdefaultでlocalに残り、network機能が送信する内容もdocument化されています。

#### 注意点

- 既存GitHub / GitLab discussionの取得と新しいplatform reviewの投稿は確認できましたが、critのように「既存threadへのreply、edit、
  delete、resolutionをpull / pushする」と明記された同期commandは確認できませんでした。既存thread中心の運用では事前検証が必要です。
- installerはhook、skill、agent別設定まで扱います。多agent対応は強みですが、binary単体のdifit / critより導入範囲が広くなります。
- OSSのlink sharingは互換機能として残る一方、team共有の主方向はhosted Workspacesへ移っています。
- UI起動時のGitHub release checkには現時点でopt-outがありません。

#### 向くケース

- local diffだけでなくPR全体のdiscussion・checks・stackを1画面で理解したい
- UI組み込みAI review、Guided Review、複数VCSを重視する
- plan review hookも含む包括的なhuman-in-the-loop環境が欲しい

公式情報: [README](https://github.com/backnotprop/plannotator/blob/main/README.md)、
[Code Review documentation](https://github.com/backnotprop/plannotator/blob/main/apps/marketing/src/content/docs/commands/code-review.md)、
[Codex integration](https://github.com/backnotprop/plannotator/blob/main/apps/codex/README.md)、
[v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)

### 推奨する運用

#### 推奨: critを主review loopにする

```text
agentが実装
  → /crit でlocal diff review開始
  → userがline / range commentを付けてFinish Review
  → 起動元agentがfeedbackを検証・修正
  → critのround-to-round diffで再review
  → 指摘がなくなるまで繰り返す
```

GitHub PR作成後は次を追加します。

```bash
crit pull          # GitHub上のreview threadをlocal sessionへ取り込む
crit push --dry-run
crit push          # local reply / comment / review outcomeをGitHubへ返す
```

remoteへの投稿はagentに無条件で任せず、最初は`--dry-run`結果を確認する運用を推奨します。

#### Plannotatorを再評価する条件

次をcritより重視するようになったら、Plannotatorを小規模repositoryで並行評価する価値があります。

- PR description、checks、全discussion、stacked PRを含むreview cockpit
- Guided Reviewや複数providerのAI review
- GitButler / Perforceを含む複数VCS
- automatic plan review hook

その評価では、GitHub上の既存inline threadに対するreply / resolveが期待どおりのthreadへ紐づくかを最優先で検証します。

#### difitを残す条件

stdin patchの確認や、GitHub書き戻しを必要としない一時的なlocal diff reviewでは、difitの軽さが有利です。ただし今回の
主workflowをdifitへ置き換える理由は薄く、critの補助toolとしても用途が重複します。tool数を減らしたい場合は導入を見送ります。

### 最終判断

| 順位 | tool            | 判断                                                                                             |
| ---- | --------------- | ------------------------------------------------------------------------------------------------ |
| 1    | **crit**        | 採用継続。必須条件とGitHub双方向連携を最も明確に満たし、既存devcontainer integrationも利用できる |
| 2    | **Plannotator** | 高機能な比較候補。PR cockpit・AI review・複数VCSが必要になった時に試験導入する                   |
| 3    | **difit**       | 軽量viewerとしては良いが、GitHubへのwrite-back不足のため今回の主workflowには採用しない           |

したがって、前回案のようにdifitをcritと並ぶ常設review loopとして追加するのではなく、**現状はcritへ一本化**し、
Plannotatorは上記の再評価条件が生じた時に検証する方針を推奨します。
