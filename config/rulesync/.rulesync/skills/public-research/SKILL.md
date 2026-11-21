---
name: public-research
description: 公開 X 投稿の URL を FxTwitter で読む、YouTube 動画をキーワードで探す、または GitHub の公開情報を調べるときに使う。
targets:
  - claudecode
  - codexcli
---

# 公開情報の調査

- 公開 X 投稿の本文・引用・添付メディアは `agent-reach read 'https://x.com/USER/status/ID'` で取得する。ログインは不要。結果の出典には元の投稿 URL を使う。
- YouTube 動画は `agent-reach youtube search '検索語' --limit 5` で探す。結果からタイトルと動画 URL を示す。アクセス制限で取得できない場合は、利用できるウェブ検索で YouTube 動画を探す。
- GitHub は既存の `gh` を使う。検索には `gh search repos`、`gh search issues`、`gh search prs`、詳細には `gh repo view`、`gh issue view`、`gh pr view` を使う。
