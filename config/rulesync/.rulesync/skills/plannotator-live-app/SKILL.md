---
name: plannotator-live-app
description: devcontainer 内のローカルアプリをホストブラウザで確認し、Plannotator でレビューを受けるときに使う。依存サービスの起動、SSH リバーストンネルの準備、レビュー終了までの待機を扱う。
targets:
  - claudecode
  - codexcli
  - copilot
  - copilotcli
---

# Plannotator でローカルアプリをレビューする

1. プロジェクトの手順に従って frontend、backend、Supabase など必要なサービスを起動し、各サービスがコンテナ内で待ち受けていることを確認する。
2. ホストブラウザが直接接続するポートを確認する。アプリの URL に加え、API、Supabase、アセットサーバーなども含める。Plannotator が自動で転送するのは annotation editor と live-app proxy のポート。
3. このスキルに同梱の `scripts/annotate.sh` にアプリの URL と上記すべてのポートを渡す。スクリプトは既存の `ensure-plannotator-tunnel` でポートを順に準備し、全部成功したら Plannotator をフォアグラウンドで起動する。失敗した場合はエラーの原因を解消してから再実行する。

   Expo Web が `8081`、API が `3000`、Supabase API が `54321` の場合、このスキルのディレクトリから次を実行する。

   ```bash
   bash scripts/annotate.sh http://localhost:8081 8081 3000 54321
   ```

4. ホストブラウザからレビュー画面を開き、実際の接続経路で画面操作、API リクエスト、認証などを確認する。実行ツールがセッション ID を返した場合は同じセッションをポーリングし、レビュー担当者がフィードバックを送信するかセッションを閉じるまで、プロセスを終了、バックグラウンド化、再起動せずに待つ。
