---
root: true
targets:
  - claudecode
  - codexcli
  - copilot
  - copilotcli
globs:
  - "**/*"
---

# 開発ルール

- 必ず日本語で回答してください。

## コードレビュー・技術調査後のメモ記録

- PR レビューや技術調査が一区切りついたら、理解した内容を `plan/` ディレクトリ配下の `10-memo-xxx.md` のようなメモファイルに加筆する。該当するメモファイルがあれば追記し、無ければ新規に作成する。ただし、追記先のファイルが指定された場合はそのファイルに加筆する
- 「マークダウンに加筆して」「メモして」などと指示されたら、`plan/` ディレクトリ配下の `10-memo-xxx.md` のようなメモファイルに加筆する。該当するメモファイルがあれば追記し、無ければ新規に作成する。ただし、追記先のファイルが指定された場合はそのファイルに加筆する

## 同種ファイルへの修正適用

- 複数の同種ファイルに同じ修正を適用する場合、Glob ツールで対象ファイルを先に全件洗い出してから修正する
- 修正対象の一部だけに適用してユーザーへの確認なしに完了報告しない

## コード変更の前に確認する

- リファクタリングや実装方針の「案」を求められた場合は、コードを変更せずに提案のみを行う
- 実装（ファイル編集）は「実装して」「コードに反映して」など、変更を明示的に依頼された場合のみ行う

## Local development environment

- devcontainer内でPlannotatorのreview画面を起動したら、reviewerがfeedbackを送信するかsessionを閉じるまで、`plannotator annotate`のprocessを終了、background化、または再起動せずに待つ
- frontend、backend、databaseなど、host browserからaccessされるlocal serviceを起動するときは、次の順序を守る
  1. frontendとbackendのdevelopment server、およびSupabaseなど依存するlocal serviceを起動し、それぞれがcontainer内でlistenしていることを確認する
  2. host browserからaccessするすべてのportについて、`~/.config/devcontainer/scripts/ensure-plannotator-tunnel <port>`を実行し、SSH reverse tunnelを準備する
  3. 必要なportをすべて準備してから`plannotator annotate <URL> --app`をforegroundで起動する
- Plannotatorが自動で転送するのはannotation editorとlive-app proxyのportだけである。live appがbrowserから直接accessするAPI、Supabase、asset serverなどのportは自動転送されないため、漏れなく個別に`ensure-plannotator-tunnel`を実行する
- container内の`curl`だけで動作確認を完了しない。host browserと同じ経路でも画面操作、API request、認証などを確認する
- 例: Expo Webが`8081`、APIが`3000`、Supabase APIが`54321`でlistenする場合は、各serviceの起動後、Plannotatorの起動前に次を実行する

  ```bash
  ~/.config/devcontainer/scripts/ensure-plannotator-tunnel 8081
  ~/.config/devcontainer/scripts/ensure-plannotator-tunnel 3000
  ~/.config/devcontainer/scripts/ensure-plannotator-tunnel 54321
  plannotator annotate http://localhost:8081 --app
  ```

## コミットの粒度

- コード実装を依頼されている場合は、変更を未コミットのまま溜め込まず、意味のある作業単位が完了するたびにコミットする
- 1コミットには、単独で説明・レビューできる1つの目的に必要な変更だけを含める
- 無関係な機能追加、リファクタリング、フォーマット変更、依存関係更新、ドキュメント更新を同じコミットに混在させない。密接に関連し、分離すると不完全になる変更は同じコミットに含めてよい
- ステージ前に `git status --short`、`git diff`、`git diff --cached` で対象と既存の変更を確認し、意図したファイルだけをステージする。ステージ後に `git diff --cached`、`git diff --check`、`git diff --cached --check` でコミット内容を再確認する。既存の未コミット変更や他者の変更はコミットしない
- 各コミット時点で、可能な範囲のテスト・型チェック・lintを通し、ビルド可能で一貫した状態にする
- コミットメッセージは変更の目的が分かる簡潔な命令形にし、リポジトリに既存の規約がある場合はそれに従う
- 大きな実装は、準備的なリファクタリング、機能実装、テスト、ドキュメントなど、レビュー可能で依存関係が自然な順序のコミットに分割する。ただし、各コミットが壊れた中間状態にならないようにする
- コミットの実行を禁止された場合、またはユーザーによる確認が必要な場合はコミットせず、その理由と推奨するコミット分割を報告する

## PR作成後のレビュー対応

- git push と PR 作成までを依頼された場合は、PR を作成した時点で完了とせず、レビュー対応が終わるまで自律的に対応を続ける
  - この自律対応では、修正・コミット・push のたびにユーザーの承認を求めない。ユーザーが `review-fix` skill を明示的に呼び出した場合は、skill の確認手順に従う
  1. PR のレビューコメント（人間・bot の両方）と CI の結果を監視する
  2. レビュー指摘ごとに妥当性を確認し、妥当なものは修正してコミット・push する。修正しない指摘には、その理由をレビューのスレッドに返信する
  3. CI が失敗した場合は、ログから原因を調査して修正し、コミット・push する
  4. push 後は再びレビューと CI を監視し、新しい指摘があれば 2 に、CI の失敗があれば 3 に戻る
  5. 依頼済みのレビュー（人間・bot の両方）がすべて届き、未対応のレビュー指摘が無く、CI が通った状態になったら、対応内容をまとめてユーザーに報告して終了する。CI が通っただけで、まだ届いていないレビューがある段階では終了しない。ただし、一定時間待っても届かないレビューは未着として報告し、終了する
- 監視は `gh pr view` / `gh pr checks` / `gh api` などで状態を確認し、反映を待つ間は一定間隔で再確認する。短い間隔で無限にポーリングし続けない
- 次の場合は自己判断で進めず、状況と選択肢をまとめてユーザーに確認する
  - 設計方針の変更や大規模なリファクタリングなど、PR の範囲を大きく超える指摘
  - 指摘同士が矛盾している、または指摘の意図が読み取れない
  - 同じ指摘や CI の失敗が修正後も繰り返し発生し、原因を特定できない
- テストの skip・無効化や、force push による履歴の書き換えでレビューや CI を通そうとしない
