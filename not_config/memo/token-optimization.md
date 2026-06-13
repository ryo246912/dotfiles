# Token Optimization Tools for Claude

このドキュメントでは、Claude Code や MCP を使用する際のトークン使用量を削減し、コンテキストを効率的に活用するためのツールを紹介します。

## 1. RTK (Rust Token Killer)

- **概要**: ターミナル出力をフィルタリングしてコンテキストへの過剰な入力を防ぐツール。
- **URL**: [https://github.com/rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- **効果**: 開発コマンドの出力を 60-90% 削減。
- **使い方**: コマンドの出力を `rtk` にパイプします。例: `npm test | rtk`

## 2. Context Mode

- **概要**: Playwright や GitHub ツールの巨大な出力を SQLite にオフロードし、クリーンな要約のみを会話に渡す。
- **URL**: [https://github.com/mksglu/context-mode](https://github.com/mksglu/context-mode)
- **効果**: 出力トークンを最大 98% 削減。
- **使い方**: MCP サーバーとして設定し、ブラウザ操作や GitHub 連携時に使用します。

## 3. code-review-graph

- **概要**: Tree-sitter を使用してローカル知識グラフを構築し、必要なコード部分のみを読み込む。
- **URL**: [https://github.com/tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph)
- **効果**: 大規模モノレポで 49 倍の削減。
- **使い方**: プロジェクトルートでグラフを生成し、Claude にそのグラフを参照させます。

## 4. Token Savior (Recall)

- **概要**: シンボル単位でコードを参照する MCP サーバー。ファイル全体を読み込まずにナビゲーションが可能。
- **URL**: [https://github.com/Mibayy/token-savior](https://github.com/Mibayy/token-savior)
- **効果**: トークン使用量を 97% 削減。
- **使い方**: MCP サーバー `io.github.Mibayy/token-savior-recall` を設定に追加します。

## 5. Caveman Claude

- **概要**: Claude に「洞窟人（Caveman）」のようなトーンで話させることで、冗長な説明を省き出力を短縮する。
- **URL**: [https://github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
- **効果**: 出力トークンを 65-75% 削減。
- **使い方**: `CLAUDE.md` に「洞窟人モード」のプロンプトを追加するか、セッション開始時に指示します。

## 6. claude-token-efficient

- **概要**: `CLAUDE.md` に記述するだけでレスポンスを簡潔に保つためのルールセット。
- **URL**: [https://github.com/drona23/claude-token-efficient](https://github.com/drona23/claude-token-efficient)
- **効果**: コード変更不要で冗長性を排除。
- **使い方**: 推奨されるルールを `CLAUDE.md` の `Guidelines` セクションにコピーします。

## 7. token-optimizer-mcp

- **概要**: キャッシュ、圧縮、スマートツール制御を備えた MCP サーバー。
- **URL**: [https://github.com/ooples/token-optimizer-mcp](https://github.com/ooples/token-optimizer-mcp)
- **効果**: 繰り返しのツール出力を圧縮し、95% 以上削減。
- **使い方**: MCP サーバー設定に `token-optimizer-mcp` を追加します。

## 8. claude-token-optimizer

- **概要**: プロジェクトを最適化するための再利用可能なセットアッププロンプト集。
- **URL**: [https://github.com/nadimtuhin/claude-token-optimizer](https://github.com/nadimtuhin/claude-token-optimizer)
- **効果**: わずか 5 分でトークンの 90% を節約。
- **使い方**: `token-optimization.md` などのドキュメントをプロジェクトに配置し、Claude に読み込ませます。

## 9. token-optimizer

- **概要**: コンテキストを消費している「ゴーストトークン」を発見し、圧縮する。
- **URL**: [https://github.com/alexgreensh/token-optimizer](https://github.com/alexgreensh/token-optimizer)
- **効果**: 品質を維持したままコンテキストを圧縮。
- **使い方**: CLI ツールとして実行し、不要なトークン消費を特定します。

## 10. claude-context (by Zilliz)

- **概要**: BM25 とベクター検索を組み合わせて、コードベース全体から必要な情報のみを抽出する。
- **URL**: [https://github.com/zilliztech/claude-context](https://github.com/zilliztech/claude-context)
- **効果**: 検索精度を維持しつつトークンを約 40% 削減。
- **使い方**: MCP サーバーとして導入し、大規模な検索が必要な際に活用します。
