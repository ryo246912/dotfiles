# meat

[meat](https://github.com/boldsoftware/meat)（`meat.dev`）は、git の diff を LLM に通して
**「読むべき差分（reading diff）」に要約する CLI ツール**です。スタイル修正・nil チェック・
import の増減といった「読まなくてよい部分」を落とし、概念・アルゴリズムの選択・アーキテクチャなど
**レビューで本当に重要な変更だけ**を残します。

エージェントが書いたコードを人間がレビューする前段として使うことを想定しており、README でも
「エージェントに `meat` を devtools として組み込ませ、コミットを事前処理させておくとよい」と
勧められています。**本 dotfiles でも AI エージェントを devcontainer 内で実行する前提**で、
`crit` と同じく devcontainer 側に導入しています。

## 構成

| 項目           | 設定                                                              | 場所                                |
| -------------- | ----------------------------------------------------------------- | ----------------------------------- |
| バイナリ       | `go:meat.dev/cmd/meat` を mise の go backend で導入               | `dot_config/devcontainer/mise.toml` |
| ビルド依存     | `core:go`（同じ devcontainer mise.toml に既に存在）               | `dot_config/devcontainer/mise.toml` |
| バージョン固定 | リリースタグが無いため **go の擬似バージョン（コミット）** で固定 | `dot_config/devcontainer/mise.toml` |
| キャッシュ     | `~/.meat` に結果を保存（下記「キャッシュ」参照）                  | 実行時に自動生成                    |
| 認証           | `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`（利用者が付与）            | —                                   |

`meat` は Go 製で、mise の go backend が `go install` でビルドします。ビルドには Go が必要ですが、
devcontainer mise.toml には既に `core:go` があるため追加の依存は不要です。

> [!NOTE]
> meat には GitHub リリースが無く、go proxy 上も擬似バージョン（`v0.0.0-<日時>-<コミット>`）しか
> 存在しません。本 dotfiles は「バージョンを固定する」方針のため、`latest` ではなく擬似バージョンで
> ピン留めしています（`http:` backend でコミットハッシュを固定しているのと同じ考え方）。更新方法は
> 後述の「バージョンの更新」を参照。

## 使い方

devcontainer 内で（エージェントまたは自分が）`meat` を実行します。基本は git ライクな引数で
対象コミット・範囲を指定します。

```bash
meat                    # 直近のコミット(HEAD)を要約
meat <revision>         # 特定コミット/リビジョン(sha, HEAD~3 など)を要約
meat <range>            # コミット範囲(sha1..sha2, main...HEAD など)の差分を要約
meat -staged            # ステージ済みの変更(git diff --staged)を要約
meat -w                 # 未ステージの作業ツリーの変更(git diff)を要約
git show <sha> | meat   # stdin にパイプした diff を要約
git diff | meat         # 作業ツリーの diff をパイプして要約
```

対話端末では `git show` のように git のページャ・`color.diff` 設定に従って色付き・ページング表示され、
パイプ・リダイレクト時はプレーンなテキストになります。出力は「要約された diff＋1 行サマリ」です。

### フラグ

| フラグ            | 説明                                                           |
| ----------------- | -------------------------------------------------------------- |
| `-model <string>` | 使用モデル（既定は `$MEAT_MODEL` または組み込みの既定モデル）  |
| `-no-cache`       | キャッシュを無視して再計算する（結果はキャッシュに反映される） |
| `-staged`         | ステージ済みの変更を対象にする（`git diff --staged`）          |
| `-w`              | 未ステージの作業ツリーの変更を対象にする（`git diff`）         |
| `-json`           | 結果を JSON で stdout に出力（色・ページャなし）               |
| `-h`, `--help`    | ヘルプを表示                                                   |

## 認証とモデル

meat は LLM を呼ぶため API キーが必要です（`exe.dev` VM で `llm` インテグレーションが付いている
場合のみキー不要でマネージド gateway を使う、という記述もありますが本環境は該当しません）。

| 環境変数             | 用途                                                       |
| -------------------- | ---------------------------------------------------------- |
| `OPENAI_API_KEY`     | OpenAI モデル（組み込みの既定モデルを含む）の API キー     |
| `OPENAI_BASE_URL`    | 任意。OpenAI API のベース URL を上書き                     |
| `ANTHROPIC_API_KEY`  | Claude モデルの API キー                                   |
| `ANTHROPIC_BASE_URL` | 任意。Anthropic API のベース URL を上書き                  |
| `MEAT_MODEL`         | 任意。既定モデル ID                                        |
| `MEAT_CACHE`         | 任意。キャッシュディレクトリ（既定 `~/.meat`／空で無効化） |

> [!IMPORTANT]
> **API キーは devcontainer.json の `remoteEnv` に恒久設定していません。**
> 特に `ANTHROPIC_API_KEY` をコンテナ全体に設定すると、`claude-code` がサブスクリプションの
> OAuth 認証ではなく **API 従量課金** に切り替わってしまうためです。meat を使うときは、その
> セッション・その呼び出しに閉じてキーを渡してください（例: `MEAT_MODEL=... ANTHROPIC_API_KEY=... meat`）。

## キャッシュ

結果は `~/.meat` に、`(ルーブリック/コンパイラのプロトコル + モデル + diff の内容)` の SHA をキーに
キャッシュされます。したがって、

- 同じ diff を再実行 → 即座に結果が返る
- diff を編集した／モデルを切り替えた／meat 本体のルーブリック・不変条件が更新された → 再計算される

キャッシュを無視して再計算したいときは `-no-cache`、キャッシュディレクトリを変えたい・無効化したい
ときは `MEAT_CACHE` を使います。

> [!NOTE]
> meat は大きな diff をファイル境界・hunk 境界で分割し、チャンク単位（数 MB まで）で要約してから
> 1 つの reading diff にマージします。巨大なコミットでも 1 つの要約になりますが、その分だけ処理に
> 時間がかかります。事前にエージェントへ処理させておくと待ち時間を隠せます。

## バージョンの更新

meat はリリースタグが無いため、mise の `go:` backend では **go の擬似バージョン**（最新コミットを
指す `0.0.0-<日時>-<コミット短縮ハッシュ>`）で固定しています。新しいコミットに追随するには、
go proxy から最新の擬似バージョンを取得して `dot_config/devcontainer/mise.toml` を書き換えます。

```bash
# 最新の擬似バージョンを取得（Version フィールドの先頭 "v" を除いた値を toml に書く）
curl -s https://proxy.golang.org/meat.dev/@latest
# => {"Version":"v0.0.0-YYYYMMDDHHMMSS-xxxxxxxxxxxx", ...}
```

取得した `v0.0.0-...` の先頭 `v` を除いた文字列を、mise.toml の
`"go:meat.dev/cmd/meat"` の値に設定します（mise の go backend が先頭に `v` を補います）。
反映後は `chezmoi apply` → devcontainer 側で `mise install` でビルドされます。

> [!NOTE]
> リリースが無いため、Renovate による自動更新 PR は基本的に作られません。更新は上記の手順で
> 手動で行います。

## crit との違い・併用

| ツール | 何をする                                                                                       | 実行形態                         |
| ------ | ---------------------------------------------------------------------------------------------- | -------------------------------- |
| `crit` | プラン・diff・フロントエンドをブラウザでレビューし、コメントを直接エージェントへフィードバック | Web UI（ホストのブラウザで開く） |
| `meat` | diff を LLM で要約し、「読むべき差分」だけを端末に出力                                         | CLI（端末に出力）                |

`crit` は **レビューのループ（コメント→修正）を回す** ための対話 UI、`meat` は **差分を読む前に
ノイズを削って理解を速める** ための前処理、という住み分けです。両方とも devcontainer 内で
エージェント／自分が実行できます（詳細は [crit](crit.md) を参照）。
