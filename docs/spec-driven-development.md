# 軽量な仕様駆動開発 workflow の選定と運用

この文書は、最初の仕様案を作った後に壁打ちで穴を見つけ、仕様へ戻してから画面設計・task分解・AI実装へ進むための
比較・運用ガイドです。

結論は、**まず[OpenSpec](https://github.com/Fission-AI/OpenSpec)を主軸として試す**ことです。Spec Kitはcoverage検査が
充実する一方、今回重視する「文書量を抑え、作った仕様へ後から判断を反映する」用途には重めです。OpenSpecは
proposal・delta spec・design・tasksという小さなartifactを任意の時点で更新でき、`update`が既存artifact間の整合を
取り直し、`verify`が実装との差を検査します。

> [!IMPORTANT]
> framework名よりgateの設計が重要です。「taskがすべてchecked」だけを完了条件にせず、要件・scenario → task → test →
> codeのtraceabilityと、実装後の独立検証を必須にします。

## 調査した候補

2026-08-15時点の各公式repositoryと同梱workflowを確認しました。star数ではなく、artifact量、仕様を後から直せるか、
実装・検証の仕組み、導入負荷で比較しています。

### 有力候補

| 候補                                               | 特徴                                                                                            | 実装漏れへの防御                                      | 分量・導入負荷                                   | 判断                                                                      |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | proposal・delta spec・design・tasksを変更単位で管理。`update`で既存artifactを相互に再整合できる | requirement / scenarioとtaskを`verify`で実装に照合    | **軽い**。Node CLI、30以上のagentに対応          | **第一候補**。今回の「仕様案 → grill → 仕様へ反映」に最も素直             |
| [Superpowers](https://github.com/obra/superpowers) | brainstorming → design承認 → plan → taskごとのsubagent実装。TDDと2段階reviewを強制              | taskごとにspec compliance reviewとcode quality review | **軽〜中**。skill中心で自動発火                  | 実装品質の補助に有力。ただし要件台帳の差分管理はOpenSpecほど明示的でない  |
| [cc-sdd](https://github.com/gotalab/cc-sdd)        | Kiro風のrequirements → design → tasksと、taskごとのfresh implementer / independent reviewer     | EARS、task boundary、TDD、独立review、auto-debug      | **中**。17 skillsとphase gate                    | 長時間の自律実装と漏れ防止を優先する場合の第二候補                        |
| [GSD Core](https://github.com/open-gsd/gsd-core)   | Discuss → Plan → Execute → Verify → Shipをphaseごとに繰り返す                                   | fresh contextのexecutorと完了前verify、fix plan       | **中〜重**。subagent orchestrationと状態artifact | 大規模・長時間実装向け。小機能には過剰になりやすい                        |
| [Tsumiki](https://github.com/classmethod/tsumiki)  | EARS要件、設計、task、TDD、Web test / UATまで一式                                               | `task-breakdown`、TDD、`dev-verify`、UAT              | **中〜重**。導入skill数と成果物が多い            | test-firstを最優先する場合。task自体の欠落には別のtraceability gateを足す |

### 用途が合えば候補になるもの

| 候補                                                              | 得意なこと                                                                    | 今回の主軸にしない理由                                                        |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [Conductor](https://github.com/gemini-cli-extensions/conductor)   | project context、featureごとのspec / plan、実装後reviewと修正task追加         | setup時のproduct・guideline・tech stack等のartifactが増える                   |
| [Agent OS](https://github.com/buildermethods/agent-os)            | codebase標準をagentへ注入し、product planとspecをshapeする                    | 仕様策定には良いが、公開workflow上の実装後coverage監査は薄い                  |
| [LeanSpec](https://github.com/codervisor/leanspec)                | 2K token未満を目安にした小さいspec、Markdown / GitHub Issues / ADO等のbackend | spec管理・検索・dashboardが中心で、厳格な実装loopは利用側で設計する必要がある |
| [Spec Workflow MCP](https://github.com/Pimzino/spec-workflow-mcp) | requirements → design → tasksの承認、dashboard、進捗・implementation log      | MCP serverと別processのdashboardを運用する必要がある                          |
| [Spec Kitty](https://github.com/Priivacy-ai/spec-kitty)           | work package、worktree、review / accept / merge、audit trail                  | team向けgovernanceが強く、個人の軽量flowには重い                              |
| [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD)       | Analyst、PM、UX、Architect等の専門roleを含むproduct discovery                 | 小〜中規模機能にはroleと成果物が過剰になりやすい                              |
| [GitHub Spec Kit](https://github.com/github/spec-kit)             | constitution、clarify、checklist、artifact間analyze、実装後converge           | 漏れ検査は強いが、厳格なphaseとMarkdown量が今回の希望より多い                 |

Pimzinoの旧[Claude Code Spec Workflow](https://github.com/Pimzino/claude-code-spec-workflow)は開発の中心がMCP版へ移行済みのため、
新規採用候補から外します。また、単にprompt templateを複製する小規模projectは候補が多いものの、更新・検証・複数agent対応の
いずれかが弱いものはpilot対象に含めません。

## 選定方針

1. **OpenSpecを2〜3機能でpilot**し、同程度のTsumiki利用実績と比較する。
2. 実装の自律性を上げたい場合だけ、cc-sddまたはSuperpowersを別pilotにする。同一featureで複数frameworkのartifactを
   二重生成しない。
3. 次を計測する: artifact総行数、要件からtaskへのcoverage、受け入れscenarioのtest化率、実装後に見つかった漏れ、
   人間のreview時間、仕様変更の反映時間。
4. OpenSpecの`verify`はcode検索を含むheuristicな検査なので、test実行と人間の受け入れ確認を置き換えない。

## 推奨 workflow: OpenSpec → grill → update

```mermaid
flowchart LR
    A[依頼・制約] --> B[OpenSpec propose: 仕様案]
    B --> C[人間が一次review]
    C --> D[grill-me: 仕様案を反証]
    D --> E[decision logを承認]
    E --> F[OpenSpec update: 既存仕様へ反映]
    F --> G[validate・人間が再承認]
    G --> H[wireframe-spec]
    H --> I[画面上の新判断をupdate]
    I --> J[task coverage gate]
    J --> K[apply: 小batch実装]
    K --> L[test・browser確認]
    L --> M[verify: 実装差分監査]
    M -->|残差あり| F
    M -->|合格| N[archive・PR]
```

### 0. OpenSpecをprojectへ導入する

OpenSpecは対象repositoryごとに初期化します。APMからskillだけを抜き出さず、CLIが対象agent用の最新command / skillを生成する
公式手順を使います。

```bash
npm install -g @fission-ai/openspec@latest
cd <project>
openspec init
```

以下ではClaude Codeのcanonical表記`/opsx:<command>`を使います。Codexでは生成された`$openspec-<command>`を使います。

### 1. まず仕様案を作る

最初から質問だけを始めるのではなく、現在分かっている範囲をreview可能なartifactへ固定します。

```text
/opsx:propose <feature-name>
目的: <達成したい結果>
対象user: <user>
既決事項: <変更しない判断>
制約: <期限・互換性・security・運用>
```

`propose`は通常、proposal、delta spec、design、tasksを一度にdraftします。この時点のtaskは実装許可ではなく、仕様の穴を
探す材料です。生成後に、最低限、scope、requirement / scenario、仮定、未決事項を人間が一次reviewします。

artifactを1つずつ承認したい場合だけexpanded profileを有効にし、`/opsx:new`と`/opsx:continue`を使います。分量削減が
目的なら、まずdefaultのcore profileで十分です。

### 2. 作成済み仕様を`grill-me`で詰める

`grill-me`には一般的なアイデアではなく、OpenSpec changeのproposal・spec・design・tasksを読ませます。事実調査はagentに任せ、
userにしか決められないproduct判断だけをdecision treeの順に質問させます。

```text
/grill-me
OpenSpec change `<feature-name>` の既存artifactをすべて読んでから、仕様を反証してください。
特に対象user、scope外、権限、data lifecycle、失敗・retry、競合、互換性、migration / rollback、
accessibility、観測性、成功指標、各scenarioのtest可能性を確認してください。
repositoryから調査できる事実は質問せず自分で確認してください。
終了時は「決定事項」「変更する要件」「追加scenario」「scope外」「未決事項」「risk」に整理し、
まだartifactやcodeを編集せず、私の承認を待ってください。
```

この順序なら、質問が抽象論にならず、既存仕様の具体的な文言・欠落を対象にできます。`grill-me`の会話ログ自体はsource of
truthにせず、次のstepで必ずartifactへ反映します。

### 3. grillの結果を`update`で仕様へ戻す

承認したdecision logを`/opsx:update`へ渡します。`update`はplanning artifactだけを対象に、変更点を1 artifactずつ提示して
承認を取り、proposal・spec・design・tasksの前後方向の不整合を直します。未作成artifactを勝手に作らず、codeも変更しません。

```text
/opsx:update <feature-name>
以下はgrill-me後に承認したdecision logです。既存artifactへ反映してください。
要件には安定したID、各requirementには観測可能なscenarioを付け、削除・scope外も明記してください。
taskには対応する要件ID、test、依存関係、完了条件を持たせてください。
各artifactの変更案と理由を先に示し、私の承認後に1つずつ更新してください。

<承認済みdecision log>
```

反映後は`openspec validate <feature-name> --strict`を実行し、`git diff -- openspec/changes/<feature-name>`を人間がreviewします。
ここが**仕様承認gate**です。grillで決まった事項がchatにしか残っていない、または古いtaskが残る場合は先へ進みません。

### 4. `wireframe-spec`で画面を固め、判断を再反映する

更新済みspecを入力に、happy pathだけでなくempty、loading、partial、error、permission denied、offline、長文、mobileを対象に
annotated wireframeを作ります。

```text
/wireframe-spec
OpenSpec change `<feature-name>` の承認済みrequirement / scenarioに対応するdesktop・mobileのlow-fi wireframeを
docs/design/<feature-name>/wireframe.mdへ作ってください。各要素へ要件ID、content priority、interaction、data source、
keyboard操作、focus順を注記し、empty / loading / error / permission denied状態を含めてください。
```

`wireframe-spec`は画像生成ではなく注釈付きlayout仕様です。必要ならそこからHTML prototypeを作りbrowserで確認します。
画面reviewで新しい仕様判断が出たら、wireframeだけへ書き足さず、もう一度`/opsx:update`でspec・design・tasksへ戻します。

### 5. 実装前にtask coverageを確認する

OpenSpecのartifact検証に加え、AIへtraceability表を作らせます。次が0件になるまで`apply`しません。

- taskへmapされないrequirement / scenarioと非機能要件
- requirementへmapされないtask（scope creep）
- test taskのないerror、permission、concurrency、migration / rollback
- spec・design・wireframe・tasks間の用語や状態の不一致
- dependencyまたは完了条件のないtask

### 6. 小batchで実装し、`verify`する

`/opsx:apply <feature-name>`を使いますが、全件一括の完了表示を信用せず、依存関係に沿った小batchごとにtest、typecheck、lint、
diff reviewを行います。画面は実browserでdesktop / mobileと主要状態を確認します。

実装後はexpanded profileの`/opsx:verify <feature-name>`で、task完了、requirement実装、scenarioのtest coverage、design準拠を
再検査します。指摘が仕様変更なら`update`、実装漏れなら`apply`へ戻し、critical issueと未完了taskが0になってから
`/opsx:archive`とPRへ進みます。

## 最小成果物とgate

| 段階     | 必須成果物                                    | 次へ進む条件                                              |
| -------- | --------------------------------------------- | --------------------------------------------------------- |
| 仕様案   | proposal、delta spec、design、tasks           | 人間が一次review済み                                      |
| grill    | 承認済みdecision log、未決事項、scope外、risk | userがdecisionを明示承認                                  |
| 仕様反映 | 更新済みartifactとdiff                        | strict validation成功、chatだけの決定が0                  |
| 画面     | 状態別・breakpoint別wireframe                 | 全要素が要件IDへtraceでき、画面由来の判断もspecへ反映済み |
| task     | 要件ID・依存・test・完了条件付きtask          | uncovered requirement / scenarioが0                       |
| 実装     | code、test、command結果、画面確認             | batchごとのcheckがpass                                    |
| 完了     | `verify`結果、最終traceability表、PR          | critical、未完了task、未反映reviewが0                     |

## 導入したdesign skill

[`owl-listener/designer-skills`の`wireframe-spec`](https://github.com/owl-listener/designer-skills/tree/main/prototyping-testing/skills/wireframe-spec)
だけをAPMへcommit SHA pinで追加しています。suite全体を入れないのは、常時読み込まれるskill descriptionと更新対象を
必要最小限にするためです。必要になった時点で`user-flow-diagram`、`state-machine`、visual critique、design handoffを
責務ごとに個別評価します。
