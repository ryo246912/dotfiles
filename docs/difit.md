# difit 導入・活用ガイド

[difit](https://github.com/yoshiko-pg/difit) は、ローカルの Git 差分を GitHub スタイルのインターフェースで確認できる CLI ツールです。
このリポジトリでは、AI エージェントによる自動コメント機能を備えた `difit-review` スキルと組み合わせて活用します。

## 導入方法

このリポジトリでは `mise` を使用して `difit` を管理しています。

```bash
# インストール（初回のみ）
mise install

# バージョン確認
difit --version
```

## 使い方

以下の略称（zabrze abbreviations）が利用可能です：

- `df`: `difit` (現在の変更または特定のターゲット)
- `dfs`: `difit staged` (ステージング済みの差分)
- `dfw`: `difit working` (未ステージングの差分)
- `dfm`: `difit main..HEAD` (mainブランチとの差分)
- `dfr`: `difit-review` (エージェントによるコメント付き起動)

実行すると `http://localhost:4966` でブラウザが開き、GitHub のような UI で差分を確認できます。

## AI エージェントとの連携 (difit-review)

`difit-review` スキルを使用することで、AI エージェント（Claude Code 等）に変更点へのコメントを生成させた状態で `difit` を起動できます。

### 実行方法

Claude Code のターミナル等で以下のように入力します：

```bash
/difit-review
```

エージェントが現在の差分を分析し、コードの意図や注意点を行単位でコメントした状態で `difit` が起動します。

## Devcontainer での利用

Devcontainer 内で `difit` を使用する場合、ポート `4966` のフォワーディングが自動的に設定されています。
ブラウザからアクセスできない場合は、VS Code の「ポート」タブで `4966` が転送されているか確認してください。

---

### 調査：Devcontainer 内の Agent に対する difit-review の動作

`difit-review` は、エージェントが提供するコンテキスト（差分情報）を元に `difit --comment 'JSON_DATA'` 形式でコマンドを実行する仕組みです。
Devcontainer 内で実行されているエージェント（Claude Code 等）は、コンテナ内のファイルシステムにアクセスできるため、通常通り差分を読み取ってコメントを生成し、コンテナ内で `difit` サーバーを起動します。

ポートフォワーディング（`4966`）が設定されていれば、ホスト側のブラウザからそのコメント付きの差分画面をシームレスに確認することが可能です。
