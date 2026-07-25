# Bitwarden: Password Manager と Secrets Manager の違い

Bitwarden には **Password Manager** と **Secrets Manager** という 2 つの製品があり、
混同しやすい。結論から言うと **同じアカウント配下だが「別々の製品・別々の保管庫」で、
両者を自動同期する機能は今のところ無い**。

fnox の provider 使い分け（`docs/fnox.md`）と合わせて読むこと。

## 1. 3つの概念の違い

|                | Bitwarden **Password Manager** (`bw`)               | Bitwarden **Secrets Manager** (`bws`)                        | **Project**（SM の中の概念）                             |
| -------------- | --------------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------- |
| 何を入れる     | 人間が使う login / secure note / card 等のリッチな item | 機械が使うフラットな key→value（name・value・note だけ）      | SM の secret をグループ化する入れ物                      |
| 使う主体       | 人間（マスターパスワード / SSO でログイン）          | アプリ・CI・スクリプト（**machine account**）                | —                                                        |
| 認証           | `BW_SESSION`（`bw unlock` で発行、**期限切れあり**） | `BWS_ACCESS_TOKEN`（machine account のトークン、**期限切れしにくい / 無期限も可**） | machine account に「この project を read/write 可」と権限を割り当てる単位 |
| 有効化条件     | 個人 vault でも使える                               | **Organization が必要**（無料枠あり）                        | SM 内でのみ存在                                          |

ざっくり言うと:

- **Password Manager** = 普段使っている「パスワード金庫」。
- **Secrets Manager** = DevOps 向けの別金庫。中身は「ただの文字列 key=value」。
- **Project** = Secrets Manager の中で secret をフォルダのようにまとめ、「どの machine account が
  どこまで触れるか」を決めるスコープ。machine account は **project 単位**でアクセス権をもらう。

`secret` と `password` は Bitwarden 的にも別物として説明されている
（[違いの解説](https://bitwarden.com/blog/whats-the-difference-between-secrets-and-passwords/) /
[SM 概要](https://bitwarden.com/help/secrets-manager-overview/)）。

## 2. PM に保存済みの内容を SM / project に連携できる？

**自動連携（sync / link）はできない。** 両者はデータモデルが違う別ストアで、「PM の item を
SM の secret として参照する」ような機能は無い。実際、公式コミュニティに
[「Vault と Secrets Manager を同期したい」という要望スレッド](https://community.bitwarden.com/t/sync-items-between-bitwarden-vault-and-bitwarden-secrets-manager/93656)
が立っている＝まだ存在しない、という状況。

できるのは「**手動 or スクリプトで一度コピーする**」だけ（ライブ同期ではなくワンショットの複製）。
CLI を繋ぐとこんな形:

```sh
# PM から値を取り出し → SM の project に secret として作る（例）
val=$(bw get password "GitHub PAT(cz-git)")
bws secret create CZ_OPENAI_API_KEY "$val" <project-id>
# 引数の順番は変わることがあるので `bws secret create --help` で確認する
```

`bw`（Password Manager）と `bws`（Secrets Manager）は別 CLI。SM 側は
`bws secret list` / `bws secret create` / `bws project ...`、認証は `BWS_ACCESS_TOKEN`
（[SM CLI docs](https://bitwarden.com/help/secrets-manager-cli/)）。

## 3. この dotfiles / fnox にとっての実践的な結論

**そもそも SM に移す必要はない。** fnox は PM と SM の**両方**を provider として持っていて、
現状の設定はすでに PM を直接使っている:

- `provider = "bitwarden"` … **Password Manager** を `bw` 経由で読む
  （＝現在の `CZ_OPENAI_API_KEY` がこれ。既存の item をそのまま使える）
- `provider = "bitwarden-sm"` … **Secrets Manager** を `bws` + `BWS_ACCESS_TOKEN` で読む

判断はシンプル:

- **今のまま PM（`bitwarden` provider）で十分** … 既に vault にある item を使いたい・人間が
  `bw unlock` できる普段使いなら、これで OK。移行不要。
- **SM（`bitwarden-sm`）を足す価値があるのは** … CI や常駐アプリなど「人間がログインせずに」
  secret を取りたい場面。`BW_SESSION` の期限切れが無い `BWS_ACCESS_TOKEN` が効く。その場合だけ、
  必要な値を SM の project に手動コピーして machine account を作る。

つまり「PM の中身を SM に寄せる」のではなく、**用途で provider を使い分ける**のが fnox の設計思想
（`docs/fnox.md` の provider 使い分け表と同じ話）。`CZ_OPENAI_API_KEY` のような個人利用トークンは
PM のままで問題なく、SM は仕事の CI などが出てきたときに検討すれば十分。

## 参考

- [Bitwarden: secrets と passwords の違い](https://bitwarden.com/blog/whats-the-difference-between-secrets-and-passwords/)
- [Secrets Manager Overview](https://bitwarden.com/help/secrets-manager-overview/)
- [Secrets Manager CLI (`bws`)](https://bitwarden.com/help/secrets-manager-cli/)
- [PM ↔ SM 同期の要望スレッド（＝未実装）](https://community.bitwarden.com/t/sync-items-between-bitwarden-vault-and-bitwarden-secrets-manager/93656)
