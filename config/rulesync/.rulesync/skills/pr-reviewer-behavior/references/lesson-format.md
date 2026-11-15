# 知見ファイルの保存と参照

実行時に選択した `config.md` の実体と同じディレクトリに、`lessons/<owner>/<repo>/` を置く。
知見は設定・実行権限とは分ける。agent-lessonsの「1知見1ファイル＋frontmatter」の構成を参考にした、このスキル専用の保存先であり、agent-lessonsへ自動登録・公開はしない。

## ファイル名とfrontmatter

ファイル名は内容を示す短い小文字英数字とハイフンにする。例: `preview-login-per-origin.md`。
日付だけの名前や毎回別の名前にせず、同じ知見は既存ファイルを更新する。
owner・repo・ファイル名に `/`・`..` 等を含めて階層外へ出さない。設定と同じGit除外・保存先検査を行い、外部へ出るsymlinkを使わない。

一覧取得を追加依存なしで行うため、frontmatterは例のようにフラットなYAMLにし、値はJSON互換の数値・引用符付き文字列・1行配列にする。
本文を一覧へ読み込ませないため、titleは要点、summaryは適用場面が分かる1文にする。

```markdown
---
schema_version: 1
title: "Previewはoriginごとにログインが必要"
summary: "別previewへ移動した際は既存セッションが共有されると決めつけず、ログイン状態を確認する"
repository: "example-org/example-app"
environment: "staging"
status: "active"
created_at: "2026-11-15"
updated_at: "2026-11-15"
tags: ["preview", "login"]
evidence: ["https://github.com/example-org/example-app/pull/123"]
---

## 適用条件

別originのpreview環境で確認を始めるとき。

## 分かったこと・有効だった手順

一覧を開く前にログイン状態を確認する。ログインが必要なら、ユーザーへ同じChromeでのログインを依頼する。

## 次回の確認方法・注意点

接続に失敗しただけでは認証が原因と断定しない。到達状況とログイン画面を確認する。

## 更新履歴

- 2026-11-15: PR #123で観測した内容を記録。
```

- `repository`: 対象のowner/repo。異なるrepoの情報を混ぜない。
- `environment`: `local` / `staging` / `all`。共通の知見だけallにする。
- `status`: `active` / `retired`。無効になった知見は消さずretiredにし、訂正理由を書く。
- 日付は作成・更新したユーザーの現地日付。上の値は入力例であり、そのまま今回の日付にしない。
- 根拠に秘密値付きURLや個人情報を記載しない。本文にもパスワード・トークン・メール・一時IDを残さない。

## 最初は一覧だけ読む

```bash
python3 <skill>/scripts/list_lessons.py --config <今回のconfig.md> --repo <owner/repo> --environment local
```

出力はパス・タイトル・要約・環境・タグ・更新日だけ。本文・認証設定は出力しない。
`--query <検索語>`でタイトル・要約・タグを絞れる。該当候補だけファイルを開いて本文を読む。
壊れたfrontmatterはwarningsに出るため、そのファイルだけ形式を直す。読み取れない知見を「存在しない」とみなさない。

## 既存config.mdからの移行

旧「教訓」は関連する見出しだけ調べ、次回に使うものをこの形式で移す。
内容と根拠を確認してから保存し、同じ知見が既にあるなら重複させない。
実体ファイルの保存を確認するまでは移行済みにしない。旧記録は無断で削除せず、新規知見は個別ファイルにだけ保存する。
