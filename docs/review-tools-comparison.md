# AI agent向けlocal review tool比較

調査日: 2026-08-11

## 結論

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

## 評価条件

| 優先度 | 条件                | 判定基準                                                                               |
| ------ | ------------------- | -------------------------------------------------------------------------------------- |
| 必須   | local diff review   | 未commit / staged / branch差分をbrowserで表示し、code lineまたはrangeへcommentできる   |
| 必須   | agent feedback loop | clipboardへの手動copyなしでfeedbackをagentへ返し、修正後に再reviewできる               |
| 希望   | GitHub PR連携       | PRのdiff・既存commentを取得でき、local reviewのcomment・reply・outcomeをGitHubへ返せる |
| 加点   | review支援          | plan / frontend、round間diff、AI review、複数VCS、共有、privacy、container運用など     |

## 比較サマリー

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

## 1. difit

### 条件への適合

- `difit .`、`staged`、`working`、commit / branch比較、stdin patchに対応します。
- diffのsingle line / rangeへcommentでき、agent向けskillはforeground processの終了を待ちます。review commentが返れば
  同じconversationで修正を継続できるため、`Copy Prompt`は必須ではありません。
- `difit --pr <URL>`は`gh pr diff --patch`でPR diffを取得し、未解決inline review threadを起動時commentとしてimportします。
- `--comment`によりagent側の指摘や説明をUIへ事前投入できます。

### 弱点

- GitHub連携は**read / import中心**です。local commentをGitHub reviewとして投稿するCLI、既存threadへのreply、approve / request
  changesは公式READMEとCLI optionから確認できませんでした。
- commentはbrowser localStorageへ保存されます。複数環境・複数reviewerで同期する用途には追加の仕組みが必要です。
- round-to-round専用UIは確認できず、agentが修正後にcommandを再実行してreviewを開き直す運用になります。

### 向くケース

- installとUIが軽いGitHub風local diff viewerを使いたい
- GitHubへ書き戻す必要がなく、人間からagentへの単純なfeedback loopだけでよい
- 任意のunified diffをstdinでreviewしたい

公式情報: [README](https://github.com/yoshiko-pg/difit/blob/main/README.md)、
[`difit` skill](https://github.com/yoshiko-pg/difit/blob/main/skills/difit/SKILL.md)、
[v5.0.11](https://github.com/yoshiko-pg/difit/releases/tag/v5.0.11)

## 2. crit

### 条件への適合

- local Git changeを自動検出し、single line / range commentを付けられます。
- 公式integrationの`/crit`は起動、human review待機、feedbackへの対応、再reviewをloopします。
- 修正後はround-to-round diffをsplit / unified viewで確認できます。
- `crit pull`はGitHub PR / GitLab MRのcommentを取得し、reply、edit、delete、discussion resolutionを重複なしで同期します。
- `crit push`はinline comment / replyに加え、summary、approve、request changesをremoteへ投稿できます。`--dry-run`で事前確認も可能です。

### プラスアルファ

- plan / Markdown、static HTML、running Web applicationを同じCLIでreviewできます。
- running appではcookie fileやChrome DevTools Protocolを使ったsession cookie転送にも対応します。
- agentが`crit comment`でprogrammatic commentを追加できます。
- 実験的な「Send now」はcommentを設定済みagentへ即時送信し、replyをUIへ戻します。file watchによりagentの編集もUIへ反映します。
- async share、organization visibility、self-host可能なshare server、story mode、review round通知があります。
- GitHubだけでなくGitLab.com / self-managed GitLabにも対応します。

### 注意点

- 「Send now」の`agent_cmd`へ強い権限を与える構成は便利ですが、実行可能範囲とrepositoryの信頼性を確認する必要があります。
- Web app proxyはoriginが変わるため、認証画面ではcookie転送設定が必要になる場合があります。
- 機能が多いため、diff表示だけが目的ならdifitより設定・運用項目は増えます。

### 向くケース

- 今回の条件を1つのtoolで最も確実に満たしたい
- GitHub / GitLabのreview threadをlocalと双方向同期したい
- codeだけでなくplanやrunning Web appも同じfeedback loopでreviewしたい

公式情報: [README](https://github.com/tomasz-tomczyk/crit/blob/main/README.md)、
[GitHub PR / GitLab MR sync](https://github.com/tomasz-tomczyk/crit/blob/main/README.md#github-pr-and-gitlab-mr-sync)、
[v0.18.4](https://github.com/tomasz-tomczyk/crit/releases/tag/v0.18.4)

## 3. Plannotator

### 条件への適合

- local Git diffはall changes、uncommitted、staged、unstaged、last commit、base branch比較を切り替えられます。
- diff selectionへcomment、delete、quick label、looks good、code suggestionを付け、`Send Feedback`でagentへ返せます。
- Codexでは`plannotator review`のstdoutをskillが待つ方式です。plan reviewはexperimentalな`Stop` hookからfeedbackを返し、
  version historyと差分を保ったまま同じturnでplanを修正できます。
- GitHub PR / GitLab MRはauthenticated CLIでdiff、metadata、checks、description、full discussion、inline threadを取得します。
- review先をagent sessionとplatformから選べ、GitHub / GitLabへinline / general reviewまたはapproveを投稿できます。

### プラスアルファ

- PR Overviewでdescription、checks、discussionをまとめて確認し、bot、resolved / outdated、author、textでfilterできます。
- stacked PR / MRをLayerとFull stackで切り替えられます。platformへの投稿は正しくanchorできるLayerだけに制限されます。
- Ask AI、複数agentによるAI review、変更を章立てするGuided ReviewをUI内から実行できます。
- Git、GitButler、jj、Perforceを扱えます。Git status / Tree / Commits view、stage / unstage、base fetchも備えます。
- plan、spec、Markdown、agentのlast message、HTML artifact、URLをannotationできます。
- local dataはdefaultでlocalに残り、network機能が送信する内容もdocument化されています。

### 注意点

- 既存GitHub / GitLab discussionの取得と新しいplatform reviewの投稿は確認できましたが、critのように「既存threadへのreply、edit、
  delete、resolutionをpull / pushする」と明記された同期commandは確認できませんでした。既存thread中心の運用では事前検証が必要です。
- installerはhook、skill、agent別設定まで扱います。多agent対応は強みですが、binary単体のdifit / critより導入範囲が広くなります。
- OSSのlink sharingは互換機能として残る一方、team共有の主方向はhosted Workspacesへ移っています。
- UI起動時のGitHub release checkには現時点でopt-outがありません。

### 向くケース

- local diffだけでなくPR全体のdiscussion・checks・stackを1画面で理解したい
- UI組み込みAI review、Guided Review、複数VCSを重視する
- plan review hookも含む包括的なhuman-in-the-loop環境が欲しい

公式情報: [README](https://github.com/backnotprop/plannotator/blob/main/README.md)、
[Code Review documentation](https://github.com/backnotprop/plannotator/blob/main/apps/marketing/src/content/docs/commands/code-review.md)、
[Codex integration](https://github.com/backnotprop/plannotator/blob/main/apps/codex/README.md)、
[v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)

## 推奨する運用

### 推奨: critを主review loopにする

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

### Plannotatorを再評価する条件

次をcritより重視するようになったら、Plannotatorを小規模repositoryで並行評価する価値があります。

- PR description、checks、全discussion、stacked PRを含むreview cockpit
- Guided Reviewや複数providerのAI review
- GitButler / Perforceを含む複数VCS
- automatic plan review hook

その評価では、GitHub上の既存inline threadに対するreply / resolveが期待どおりのthreadへ紐づくかを最優先で検証します。

### difitを残す条件

stdin patchの確認や、GitHub書き戻しを必要としない一時的なlocal diff reviewでは、difitの軽さが有利です。ただし今回の
主workflowをdifitへ置き換える理由は薄く、critの補助toolとしても用途が重複します。tool数を減らしたい場合は導入を見送ります。

## 最終判断

| 順位 | tool            | 判断                                                                                             |
| ---- | --------------- | ------------------------------------------------------------------------------------------------ |
| 1    | **crit**        | 採用継続。必須条件とGitHub双方向連携を最も明確に満たし、既存devcontainer integrationも利用できる |
| 2    | **Plannotator** | 高機能な比較候補。PR cockpit・AI review・複数VCSが必要になった時に試験導入する                   |
| 3    | **difit**       | 軽量viewerとしては良いが、GitHubへのwrite-back不足のため今回の主workflowには採用しない           |

したがって、前回案のようにdifitをcritと並ぶ常設review loopとして追加するのではなく、**現状はcritへ一本化**し、
Plannotatorは上記の再評価条件が生じた時に検証する方針を推奨します。
