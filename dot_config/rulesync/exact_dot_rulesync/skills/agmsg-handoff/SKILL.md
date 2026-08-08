---
name: agmsg-handoff
description: agmsg を使って CLI AI エージェント間の作業を引き継ぐ skill。Claude Code と Codex の間で、作業コンテキストの送信、引き継ぎメッセージの受信、続きの実装、完了報告を依頼されたときに使う。
---

# agmsg 作業引き継ぎ

`~/.agents/skills/agmsg/scripts/` のスクリプトだけを使う。SQLite DB、team 設定、agmsg の管理ファイルを直接読み書きしない。

## 共通準備

1. 自分の agent type を Claude Code なら `claude-code`、Codex なら `codex` とする。
2. 次を実行し、現在の project に登録された team と自分の agent ID を取得する。

   ```bash
   ~/.agents/skills/agmsg/scripts/whoami.sh "$(pwd)" <agent-type>
   ```

3. 未登録なら `$agmsg` または `/agmsg` の初期設定を案内して終了する。複数の identity が返った場合は、どれを使うかユーザーに確認する。

## 作業を引き継ぐ

1. 宛先が指定されていなければ `team.sh <team>` でメンバーを確認する。候補が1人に決まらない場合はユーザーに確認する。
2. 会話と作業ツリーから事実を収集する。少なくとも `git status --short --branch`、`git diff --stat`、`git log -1 --oneline` を確認する。必要なら差分を読み、現在の目的と未完了事項を特定する。
3. 次の形式で、受信側が元の会話を参照せず再開できるメッセージを作る。未確認のテストや完了事項を推測しない。

   ```text
   [HANDOFF]
   目的: <目的と完了条件>
   ブランチ/HEAD: <branch / commit>
   完了済み: <変更内容と主要ファイル。なければ「なし」>
   テスト: <コマンドと結果。未実施なら「未実施」>
   未完了: <次に行う具体的な作業>
   注意点: <制約、判断、不明点。なければ「なし」>
   返信要件: 変更ファイル、判断理由、テスト結果、残課題を返信すること。
   ```

4. 大きな diff やファイル全文は貼らず、共有 workspace で確認できる branch、commit、ファイルパスを記載する。
5. 次を実行して送信する。メッセージは shell の1引数として安全に渡す。

   ```bash
   ~/.agents/skills/agmsg/scripts/send.sh <team> <from-agent> <to-agent> "<message>"
   ```

6. 宛先と送信内容の要約をユーザーへ報告する。

## 作業を受け取る

1. 次を実行し、未読メッセージを取得する。

   ```bash
   ~/.agents/skills/agmsg/scripts/inbox.sh <team> <agent-id>
   ```

2. `[HANDOFF]` メッセージが複数ある場合は、送信者または対象をユーザーに確認する。該当メッセージがなければ、その旨を報告して終了する。
3. `git status --short --branch`、メッセージ記載の branch/commit、対象ファイルと差分を照合する。共有 workspace の未コミット変更を破棄、上書き、stash しない。状態がメッセージと矛盾する場合は作業を始めず、送信者へ質問する。
4. 目的、完了済み、未完了、制約を短く整理し、次の作業をユーザーへ提示する。
5. ユーザーが「続けて」「対応して」など実行も依頼している場合は、そのまま未完了作業を進める。受信確認だけの依頼なら実装を開始しない。
6. 不明点やブロッカーがあれば `send.sh` で送信者へ質問する。
7. 作業完了後にテストを実行し、次の形式で送信者へ返信する。

   ```text
   [HANDOFF-RESULT]
   結果: <完了またはブロック>
   変更: <変更内容とファイル>
   判断: <重要な判断と理由>
   テスト: <コマンドと結果>
   残課題: <残課題。なければ「なし」>
   ```

8. 実施内容と返信結果をユーザーへ報告する。
