# PR の情報を集める

review-pr / crit-pr skill の共通手順。

入力は PR の URL か番号。番号だけなら、カレントディレクトリのリポジトリ（`gh repo view --json nameWithOwner`）の PR とみなす。

```bash
gh pr view <N> --json number,title,url,author,body,baseRefName,headRefName,headRefOid,files,labels,comments,reviews
gh pr diff <N>
gh pr checks <N>
```

- **作成者**を控える。作成者が自分でないなら、ラベル変更・ブランチへの push・他人のスレッドへの返信はしない。必要ならユーザーに「作成者へ依頼してください」と伝える
- **PR 本文**から、目的・受け入れ条件・関連チケット・関連 PR・作成者が自分で書いた懸念点を拾う。関連 PR が複数あれば、この PR が受け持つ範囲を表で整理しておくと、指摘の「本 PR との関係」の判定がぶれない
- **head の SHA**（`headRefOid`）を控える。行番号はすべてこの SHA のファイルで数える
- リポジトリに規約（`CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md` など）・仕様書・動作確認の手引きがあれば、変更箇所に関係する部分だけを読む。規約違反の指摘の根拠になる
