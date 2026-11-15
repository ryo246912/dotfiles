# 監視モード（`--watch`）

pr-reviewer-brief skill の監視モード。新しく作られた PR を監視し、PR ごとに最初の 1 回だけ資料を自動で作る。作り直しは
ユーザーが手で行う。Claude Code 専用（バックグラウンドのコマンドと subagent を使う）。ユーザーは対象リポジトリで
Claude Code を立ち上げっぱなしにしておく（tmux の中など）。このセッション（メイン）は監視と依頼だけをするので、
軽いモデル（`claude --model haiku`）でよい。

**トークンを抑えるため、次を守る**

- 待っている間はモデルを動かさない。監視はスクリプトが `gh` を叩くだけで行い、対象が見つかるまで終了しない
- 資料作りは SKILL.md の段階どおり subagent に任せ、メインの会話にコードや差分を読み込まない。メインの返答は各回 1〜2 行
- 作るのは 1 件ずつ順番に

## 手順

1. **監視を始める**。Bash の `run_in_background: true` で起動し、終わるまで何もせず待つ（ポーリングしない。終わると
   通知で起こされる）。Bash の timeout は `--max-wait` より長くする

   ```bash
   python3 <skill>/scripts/watch_prs.py
   ```

   既定では、平日 9〜20 時に 10 分ごと確認し、対象が無いまま 110 分経つと空の結果で終わる。ユーザーが間隔や時間帯を
   指定したら `--interval`・`--hours`・`--weekdays` で渡す（意味はスクリプトの冒頭を参照）。対象の条件:
   - カレントディレクトリのリポジトリの open な PR のうち、まだ見ていないもの（draft と自分が作ったものは除く）
   - gh stack の stack は stack 単位で 1 件にまとめ、stack ごとに 1 回だけ出す
   - 初めて起動したときに open だった PR は対象にしない（監視を始めたあとに作られた PR だけ）

2. **結果を読む**。標準出力の最後の 1 行が JSON。`targets` の各件（`arg` が `123` か `stack 7`）について、1 件ずつ
   SKILL.md の「進め方」の段階 0〜2 を**監視モードのルール**で行う（スクリーンショットは撮らない）。終わったら通知する

   ```bash
   python3 <skill>/scripts/watch_prs.py --notify "<arg> の資料: <HTML のパス>"
   ```

   失敗したら失敗を通知し、作り直しはしない（ユーザーが手で `/pr-reviewer-brief <arg>` を実行する）

3. **1 に戻る**。ユーザーが止めるまで繰り返す

見つけた PR は `./plan/.pr-reviewer-brief/watch-state.json` に記録され、二度は出ない。
会話が長くなって自動で compact されても、`/pr-reviewer-brief --watch` を打ち直せば続きから再開できる。
