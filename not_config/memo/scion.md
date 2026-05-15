# sciON (Scientific Orchestration Network) 概要

## sciON とは？

sciONは、Google Cloud Platformによって公開された、複数のAIエージェント（Claude Code, Gemini CLI, Codexなど）を並列かつ安全に実行・管理するための実験的なマルチエージェント・オーケストレーション・テストベッドです。

名前の由来は「接ぎ木」を意味する "scion" からきています。

## 主な強み

- **高い隔離性**: 各エージェントは専用のコンテナとGit worktree内で動作します。これにより、エージェント同士が同じファイルを同時に編集して競合したり、環境を壊したりすることを防ぎます。
- **並列実行**: 複数のエージェントを同時に動かし、それぞれ別のタスクや同じプロジェクトの異なる部分を並行して進めることができます。
- **ハーネス非依存**: Claude Code, Gemini CLI, Codexなど、コンテナ内で動作するあらゆるエージェント・ハーネスに対応しています。
- **自然言語による連携**: 厳密なワークフローをコードで定義するのではなく、エージェントがCLIツールを動的に学習し、モデル自身が自然言語を通じて連携方法を決定します。
- **柔軟なランタイム**: ローカルのDocker/Podmanだけでなく、macOSのApple Container、さらにはKubernetes上でも動作可能です。

## 使い方

### 初期化

```bash
# マシンの初期化
scion init --machine

# プロジェクト（Grove）の初期化
cd your-project
scion init
```

### エージェントの起動

```bash
# エージェントを起動してセッションにアタッチ
scion start debug "このエラーの修正を助けて" --attach
```

### 管理コマンド

- `scion list` (または `ps`): 起動中のエージェント一覧を表示
- `scion attach <name>`: 実行中のエージェントのtmuxセッションに接続
- `scion message <name> "..."`: 実行中のエージェントにメッセージを送信
- `scion logs <name>`: ログを表示
- `scion stop <name>`: エージェントを停止
- `scion delete <name>`: エージェント、コンテナ、worktreeを削除

## 注意事項

sciONは現在実験的な段階にあります。ローカル利用は比較的安定していますが、機能の変更や破壊的なアップデートが行われる可能性があります。
