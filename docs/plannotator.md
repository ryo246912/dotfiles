# Plannotator / Effective HTML

## HTML artifactを作成してreviewする

[Effective HTML](https://github.com/plannotator/effective-html)のskillは、作りたいartifactに合わせて使い分けます。

| skill              | 使いどころ                                                  |
| ------------------ | ----------------------------------------------------------- |
| `$html`            | report、explainer、presentation、landing pageなどの汎用HTML |
| `$design-artifact` | palette、typography、layoutなどのvisual directionを決める   |
| `$html-wireframe`  | 情報設計や導線を確認するlow-fidelity wireframe              |
| `$html-prototype`  | 見た目を確認するmockup、または操作できるprototype           |
| `$html-plan`       | plan、roadmap、rollout、実装手順                            |
| `$html-diagram`    | architecture、sequence、process、state、hierarchyのdiagram  |

`$html`は汎用の入り口です。作るものがwireframeやprototypeと明確な場合は、
対応するspecialist skillを直接指定します。`$design-artifact`は他のskillと組み合わせて
visual directionを調整する場合に使えます。

```text
$html-wireframe 管理画面の情報階層と2つの導線案をHTMLで作成して

$html-prototype ユーザー登録から完了までの操作可能なprototypeをHTMLで作成して

$design-artifact $html-plan この実装planをprojectのdesign languageに合わせて可視化して
```

作成したHTMLはPlannotator skillからreviewできます。Plannotatorはskill実行時に起動するため、
container起動時にPlannotatorを常駐起動する必要はありません。

```text
$plannotator-annotate path/to/artifact.html
```

CLIを直接実行する場合は次を使います。

```bash
plannotator annotate path/to/artifact.html
```

## 開発中のweb siteをreviewする

最初にViteなどのdev serverをcontainer内で起動します。

```bash
npm run dev -- --host 0.0.0.0
```

別のterminalまたはagent sessionから、dev serverのloopback URLをPlannotatorへ渡します。
このdevcontainerではPlannotatorをremote modeで使うため、`--static`を指定して現在のpageを
snapshotとして取得し、pageのcontentやtextにcommentします。remote modeでは
hot reloadやpage内操作を保ったlive annotationは使えないため、状態ごとにsnapshotをreviewします。
`--no-jina`はcontainer内のdev serverへ直接accessするために指定します。

```text
$plannotator-annotate http://localhost:5173 --static --no-jina
```

CLIで直接起動する場合は次のとおりです。pathやqueryを含むURLも渡せます。

```bash
plannotator annotate 'http://localhost:5173/admin?tab=users' --static --no-jina
```

annotation UIでtextを選択してcommentするか、page全体へのcommentを追加し、
**Send Annotations**を押すとfeedbackがagentへ戻ります。pageの状態を変えた後は
review commandを再実行して、新しいsnapshotを確認します。

## code diffをreviewする

current branchの変更は次のskillでreviewします。

```text
$plannotator-review
```

GitHub PRをreviewする場合はPR URLを渡します。

```text
$plannotator-review https://github.com/owner/repository/pull/123
```

## agentの最後の返答をreviewする

```text
$plannotator-last
```
