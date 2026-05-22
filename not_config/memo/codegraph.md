# CodeGraph

CodeGraph は、Claude Code を強化するためのセマンティックなコードナレッジグラフツールです。
コードの構造、シンボルの関係、コールグラフを事前にインデックス化することで、AI エージェントによるコード探索を高速化し、トークン消費を大幅に削減します。

## 特徴

- **高速なコード探索**: grep や find を繰り返す代わりに、グラフベースの探索を行います。
- **トークン節約**: 関連するコード断片を一度に取得できるため、無駄なツール呼び出しを減らせます。
- **100% ローカル**: すべてのデータはローカルの SQLite データベースに保存されます。
- **マルチ言語対応**: TypeScript, Python, Rust, Go, Java, C++, Swift など 19 以上の言語に対応。
- **オートシンク**: ファイルの変更を監視し、インデックスを自動的に更新します。

## 導入方法

1. **インストール**
   このリポジトリでは `mise` で管理されています。

   ```bash
   mise install
   ```

2. **初期化**
   プロジェクトのルートディレクトリで以下のコマンドを実行します。

   ```bash
   codegraph init -i
   ```

   これにより `.codegraph/` ディレクトリが作成され、初期インデックスが構築されます。

3. **Claude Code の再起動**
   MCP サーバーの設定を反映させるため、Claude Code を再起動します。

## 使い方

### Claude Code 内での利用

CodeGraph が導入されたプロジェクトでは、Claude Code が自動的に CodeGraph のツール（`codegraph_explore`, `codegraph_search` など）を認識して使用します。

### CLI コマンド

- `codegraph status`: インデックスの状態と統計を表示。
- `codegraph query <search>`: シンボルを検索。
- `codegraph files`: インデックスされたファイル構造を表示。
- `codegraph affected [files...]`: 変更によって影響を受ける（テスト）ファイルを特定。

## 設定

`.codegraph/config.json` でインデックス対象や除外パターンをカスタマイズできます。

```json
{
  "version": 1,
  "languages": ["typescript", "javascript"],
  "exclude": ["node_modules/**", "dist/**", "build/**"],
  "maxFileSize": 1048576
}
```

## 連携の仕組み

1. **Extraction**: tree-sitter を使用してソースコードを解析。
2. **Storage**: シンボルと関係性をローカル SQLite に保存。
3. **MCP Server**: Claude Code などのエージェントがツール経由でグラフをクエリ。
4. **Auto-Sync**: ファイル変更を検知して増分同期。

## 関連リポジトリ

- [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph)
