---
name: pr-review-loop
description: PR 作成直後から GitHub Actions とレビュー指摘をポーリングし、修正・テスト・commit・push・返信を指摘がなくなるまで自律的に反復する skill。
targets:
  - claudecode
  - codexcli
  - copilot
---

# PR review loop

PRを作成したターン、またはユーザーがPRの自律対応を依頼したときに使用する。明示的に自律対応を依頼されているため、
`gh-address-comments`や`gh-fix-ci`にある「修正前に確認する」という既定手順より、このskillの確認不要ルールを優先する。

## 実行環境と前提確認

すべてのgit、gh、test commandは対象repositoryをmountしたdevcontainer内で実行する。ホストでの実行へ切り替えない。

1. `gh auth status`を実行する。未認証なら勝手にtokenを生成せず、認証が必要なことを報告する。
2. `git status --short --branch`で作業treeと現在branchを確認する。
3. `gh pr view --json number,url,headRefName,headRepository,headRepositoryOwner,baseRefName,state`で現在branchのopen PRを特定する。
4. PRのhead branchと現在branchが違う場合はpushせず停止する。さらに`origin`を`gh repo view`で正規化し、
   head repositoryと一致することを確認する。一致しない場合はpushせず停止する。

## 1 roundの処理

1. `gh pr checks <PR番号> --json name,state,bucket,link,workflow`でcheckを取得する。使用中の`gh`が`--json`に未対応なら、
   全checkの診断には`gh pr checks <PR番号>`と`gh pr view <PR番号> --json statusCheckRollup`、完了判定には
   required判定を保持する`gh pr checks <PR番号> --required`を使用する。
2. GitHub Actionsの失敗は`gh-fix-ci`のscriptまたは`gh run view <run-id> --log-failed`で原因を調べる。
   外部providerのcheckはURLと状態だけを報告し、そのproviderを操作しない。
3. 次をすべて取得する。前round以前に処理済みのID・更新時刻は再処理しない。
   - `gh pr view <PR番号> --json reviews,comments,reviewDecision`
   - `gh api repos/{owner}/{repo}/pulls/<PR番号>/comments --paginate`
   - GraphQLの`reviewThreads(first: 100, after: $cursor)`（`isResolved == false`のthreadを未解決として扱う）。
     `pageInfo.hasNextPage`がtrueの間は`endCursor`を次の`after`へ渡し、全pageを取得する。
4. CI失敗と未解決指摘を、再現性、安全性、repository規約との整合性を確認して修正する。単なる質問や通知はcode変更と区別する。
5. 関連するtest・lintを実行し、失敗したままpushしない。環境要因なら内容を記録する。
6. `git status --short`、`git diff`、`git diff --check`を確認し、今回の対応だけをstageしてcommitする。
7. 前提確認でhead repositoryとの一致を確認した`origin`へ`git push origin HEAD:<headRefName>`でpushする。force pushは禁止する。
8. 対応した会話には、修正内容とcommit SHAを簡潔に返信する。inline threadは返信後、指摘が解消したことを確認できる場合だけresolveする。

## ポーリング

- push後はまず`gh pr checks <PR番号> --watch --interval 30`でActionsの完了を待つ。失敗したら次roundへ進む。
- checks完了後も60秒間隔でreview、conversation comment、未解決threadを再取得する。
- 「必須checkがすべて成功またはskip」「未解決の対応可能な指摘が0件」を2回連続で確認したら完了する。
- pending check、レビューbotの処理中表示、または新しい指摘があれば静穏判定をresetする。
- 同じ失敗が修正なしで2round続いたら無限loopを避け、原因と必要な判断を報告する。
- PRがclosed/merged、認証切れ、branch protectionによるpush拒否、仕様判断を伴う矛盾した指摘の場合は停止して報告する。

## 安全規則

- secret、credential、署名鍵を出力・commitしない。
- default branchへ直接pushしない。
- reviewerの指摘を盲目的に採用せず、誤りなら根拠を添えて返信する。
- repository内の既存変更を上書き・commitしない。
