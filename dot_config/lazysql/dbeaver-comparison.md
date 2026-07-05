# DBeaver → TUI DB クライアント 対応表 (lazysql / gobang)

DBeaver の代替として [lazysql](https://github.com/jorgerojas26/lazysql) と
[gobang](https://github.com/TaKO8Ki/gobang) を検証したときの対応表です。
DBeaver でやっていることをどこまでターミナル上で再現できるかをまとめています。

## 結論: まず lazysql を使う

| 観点 | lazysql | gobang |
| --- | --- | --- |
| 実装言語 | Go | Rust |
| 最新リリース | v0.5.5 (2025-06) 活発にメンテ | v0.1.0-alpha.5 (2021-09) 事実上停止 |
| 対応 DB | MySQL / PostgreSQL / SQLite / **MSSQL** / **MongoDB** | MySQL / PostgreSQL / SQLite |
| SQL エディタ | ○ (`Ctrl-E`、外部エディタ連携も可) | △ (タブ `3`、機能は限定的) |
| データ編集 (UPDATE/INSERT/DELETE) | ○ | ×（閲覧のみ） |
| クエリ履歴 | ○ (`Ctrl-_`) | × |
| CSV エクスポート | ○ (`E`) | ×（セルコピー `y` のみ） |
| 複数タブ / 複数接続 | ○ | △（接続切替のみ） |
| JSON ビューア | ○ (`Z`/`z`) | × |
| キーマップのカスタマイズ | ○ (`[keymap.*]`) | ×（設定項目はあるが未実装に近い） |
| vim ライクな操作 | ○ | ○ |

**gobang は 2021 年の alpha 版で更新が止まっており、閲覧専用に近い**ため、
DBeaver の代替としては **lazysql を推奨**します。gobang は比較・お試し用として
残していますが、日常利用は lazysql が実用的です。

> どちらも DBeaver のような ER 図・ビジュアルなスキーマ設計・データ移行ウィザードは
> 持ちません。SQL を書いてデータを見る／編集する、という日常作業の置き換えが狙いです。

---

## セットアップ

両ツールとも `mise` (aqua backend) で管理しています。

```bash
# dot_config/mise/config.toml に定義済み
#   "aqua:jorgerojas26/lazysql" = "0.5.5"
#   "aqua:TaKO8Ki/gobang"       = "0.1.0-alpha.5"
mise install

# 設定ファイル（このリポジトリで管理 → chezmoi apply で配置）
#   ~/.config/lazysql/config.toml
#   ~/.config/gobang/config.toml
chezmoi apply

# 起動
lazysql
gobang
```

接続情報は設定ファイルに直接書けますが、**認証情報はコミットしない**でください。
lazysql は `${env:VAR}` 形式で環境変数を参照できます。gobang は `password` を
省略すると起動時に入力を求められます。

---

## DBeaver 機能 → lazysql キー対応表

DBeaver での操作を lazysql で再現する場合の対応です。lazysql は操作対象の
「グループ（パネル）」ごとにキーが定義されています。

### 接続・ナビゲーション

| DBeaver でやること | lazysql | 補足 |
| --- | --- | --- |
| 接続の一覧・切替 | `Backspace`（接続一覧へ） | 一覧で `c`/`Enter` 接続、`n` 新規、`e` 編集、`d` 削除 |
| DB ナビゲーター（ツリー）へ移動 | `H` | ツリー表示のトグルは `T` |
| データグリッド（結果）へ移動 | `L` | |
| ツリーを開く/たどる | `Enter` / `j` `k` | `g`/`G` で先頭・末尾 |
| ツリー内検索 | `/` | `n`/`N`/`p`/`P` で次/前へ |
| ツリー全展開 / 全折りたたみ | `e` / `c` | |
| スキーマ/テーブルの再読み込み | `R` | DBeaver の "Refresh" |
| ヘルプ | `?` | |
| 終了 | `q` | |

### テーブル/データ閲覧・編集

| DBeaver でやること | lazysql | 補足 |
| --- | --- | --- |
| セル間移動 | `w` / `b`（次/前）、`0` / `$`（行頭/行末） | |
| ページ送り（ページング） | `>` / `<` | 1 ページ件数は `DefaultPageSize` |
| データのフィルタ/検索 | `/` | DBeaver のグリッドフィルタ相当 |
| 列でソート | `J` / `K` | |
| セルの値を編集 | `c` | DBeaver のインライン編集 |
| 行を追加 | `o`（新規）/ `O`（複製） | |
| 行を削除 | `d` | |
| セルの値をコピー | `y` | |
| セルの全文/型メニュー表示 | `C` | |
| 列 / 制約 / インデックス / 外部キー等の表示 | `1`〜`5`（メニュータブ切替） | DBeaver の Properties タブ相当 |
| CSV エクスポート | `E` | |
| JSON セルの整形表示 | `Z` / `z` | `w` で折り返し切替 |
| サイドバー（行の縦表示）表示 | `S` / `s` | 1 行を縦に並べて確認 |
| タブ切替 / タブを閉じる | `[` `]` または `{` `}` / `X` | 複数テーブルを開ける |

### SQL エディタ・クエリ履歴

| DBeaver でやること | lazysql | 補足 |
| --- | --- | --- |
| SQL エディタを開く | `Ctrl-E` | |
| SQL を実行 | `Ctrl-R` | DBeaver の "Execute" (Ctrl+Enter) 相当 |
| 外部エディタで編集 | `Ctrl-Space` | `$EDITOR`（nvim 等）で書ける |
| クエリのプレビュー保存 | `Ctrl-S` | |
| クエリ履歴を開く | `Ctrl-_` | DBeaver の SQL History |
| 履歴の検索 / 保存 / 削除 | `/` / `s` / `d` | |
| グローバル検索 | `Ctrl-P` | |

---

## DBeaver 機能 → gobang キー対応表（参考）

gobang は閲覧が中心です。編集・エクスポート・履歴は基本的にありません。

| DBeaver でやること | gobang | 補足 |
| --- | --- | --- |
| 接続切替 | `c` | |
| スクロール移動 | `h` `j` `k` `l` | `Ctrl-u`/`Ctrl-d` で複数行 |
| 先頭 / 末尾へ | `g` / `G` | |
| 選択範囲の拡張 | `H` `J` `K` `L` | |
| フォーカス移動 | `←` / `→` | |
| データのフィルタ | `/` | |
| セルの値をコピー | `y` | エクスポートは非対応 |
| タブ切替（レコード/プロパティ/SQL/列/制約/FK/index） | `1`〜`7` | `3` が SQL エディタ |
| ポップアップを閉じる | `Esc` | |
| ヘルプ | `?` | |
| 終了 | `q` | |

---

## DBeaver にあって TUI では再現しにくいもの

lazysql/gobang どちらでも**代替できない、もしくは別手段が必要**な機能:

| DBeaver 機能 | 代替 |
| --- | --- |
| ER 図 / ビジュアルなスキーマ図 | なし（`SchemaSpy`, `tbls`, `dbdocs` 等を別途） |
| GUI のスキーマ設計・DDL 生成ウィザード | 手書き SQL、`atlas`/`sqldef` 等のマイグレーションツール |
| データ移行 / インポートウィザード | `mysqldump`/`pg_dump`、`csvkit`、`sqlite3 .import` |
| 大量データのビジュアルな一括編集 | lazysql の行編集 or 直接 SQL |
| ドライバの GUI 管理 | 各 DB クライアントを事前にインストール |
| 実行計画のビジュアル表示 | `EXPLAIN (ANALYZE)` を SQL エディタで実行 |

## 補足: 既存の関連ツール

このリポジトリには SQL 関連の `navi` チートも用意されています。
併用すると定型クエリを素早く呼び出せます。

- `dot_config/navi/cheats/sql_mysql.cheat.md`
- `dot_config/navi/cheats/postgresql.cheat.md`
- `dot_config/navi/cheats/mysql.cheat.md`
