# curl | sh インストーラの安全な扱い方

`curl -fsSL <url> | sh` 形式のインストーラ（mise の `mise.run` を含む）に対して、
「まず何が問題か」「対応策として何があるか」を調べたメモ。他のツールの
インストーラを扱うときにも流用できるよう、mise 固有ではなく一般論として整理する。

## 何が問題か

mise の `install.sh` はダウンロードしたバイナリを埋め込みチェックサムで検証してから
展開している。つまり「バイナリ自体の改ざん」は既にスクリプト内で担保されている。

残るリスクは **install.sh 自体が本物か**（配信元サーバの乗っ取り・MITM・DNS ハイジャック
で別物にすり替わっていないか）の1点。TLS はサーバの真正性は保証しても、運用主体の
乗っ取りまではカバーしない。加えて、**攻撃基盤は訪問者ごとに異なるペイロードを
返せる**ため、「一度目視で確認した内容」と「実際に `sh` に流れる内容」が一致するとは
限らない（ストリーミング実行だとそもそも目視の余地がない）。

## 対応策（層ごとの整理）

### 1. レビュー層（ツール不要、まず徹底すべき原則）

- `curl | sh` を直接叩かず、`curl -o install.sh` → 中身を読む → `sh install.sh` の
  3段階に分ける。
- バージョン/コミットを固定して取得する（`latest` を毎回引かない）。
- 可能なら複数拠点・複数回取得して diff する（visitor 別ペイロード対策）。
- shellcheck 等の静的解析にかけ、明らかな難読化・base64 展開がないか機械的にも見る。

### 2. 暗号検証層

公開されていれば最優先で使う。

- **GPG署名検証**: mise は公式に手順を提供している。
  ```sh
  gpg --keyserver hkps://keys.openpgp.org --recv-keys 24853EC9F655CE80B48E6C3A8B81C9D17413A06D
  curl https://mise.jdx.dev/install.sh.sig | gpg --decrypt > install.sh
  sh ./install.sh
  ```
- **`gh attestation verify`**（GitHub CLI 標準機能）: GitHub Actions でビルドされた
  成果物の Sigstore ベース build provenance を検証。個別バイナリにも使える。
- **`cosign verify-blob`**（sigstore）: keyless 署名検証。
- **[aqua](https://aquaproj.github.io/)**: このリポジトリでも mise の aqua backend
  経由で `gh` 等を導入済み。対応ツールなら checksum / cosign+SLSA provenance /
  minisign / GitHub Artifact Attestation を registry ベースで自動検証してくれる。
  「そもそもシェルスクリプトを実行しない」設計。

### 3. サンドボックス実行層

レビューも検証もできない・する時間がない場合の最後の砦。ホストを直接汚さず、
閉じ込めた中でインストーラを実行する。

#### Linux

| ツール | 特徴 |
|---|---|
| **[bui (bubblewrap-tui)](https://github.com/reubenfirmin/bubblewrap-tui)** | まさに `curl\|bash` installer のサンドボックス用途を謳う専用CLI。`bui --profile untrusted -- 'curl -fsSL ... \| bash'` の1行でcwd以外への読み書きを遮断、ネットワークもallowlist可能。beta品質。**Linux専用**（bubblewrap依存）。 |
| **bubblewrap (bwrap)** | Flatpakが使う非特権軽量サンドボックス。デーモン不要。bui はこのラッパー。 |
| **firejail** | プロファイル駆動。デスクトップアプリ想定だが単発コマンドにも流用可。SUIDバイナリなのでbwrapより攻撃面は広め。 |
| **[landrun](https://github.com/Zouuup/landrun)** | カーネル5.13+の Landlock をCLIラップ。root不要・超軽量。 |
| **gVisor (runsc) / Kata+Firecracker** | 本気で信用できないコード向け。ユーザー空間カーネル or microVMでホストカーネルへの直接syscallを遮断。オーバーヘッド大。 |

#### macOS

| ツール | 特徴 |
|---|---|
| **[`srt` (@anthropic-ai/sandbox-runtime)](https://github.com/anthropic-experimental/sandbox-runtime)** | **推奨。** Anthropic製、OSS。`npm install -g @anthropic-ai/sandbox-runtime` だけで導入でき、`srt "curl https://example.com/installer.sh | sh"` の1行でOK。デフォルトで**全ファイルシステム書き込み拒否・全ネットワーク拒否**（allowlistで明示的に許可）という安全側の初期値。macOS では追加依存なしで `sandbox-exec` (Seatbelt) をネイティブ利用。Linux では bubblewrap 経由、Windows もalpha対応でクロスプラットフォーム。設定ファイルなしでも動く。 |
| `sandbox-exec`（Seatbelt） | macOS標準搭載だが非推奨マーク済み・プロファイル記法がScheme風で難解。`srt` は内部でこれを使っている。 |
| Lima / OrbStack | 使い捨てLinux VMを立てて中で bui 等を使う。分離強度は高いがVM起動のオーバーヘッドあり。 |
| [sandvault](https://github.com/webcoyote/sandvault) | 専用macOSユーザーアカウント＋sandbox-execで多層防御。**永続的なエージェントセッション向け**の設計で、単発インストーラには重い。 |

#### Windows

- **Windows Sandbox**（Pro/Enterprise/Education標準搭載）: 使い捨てデスクトップVM。閉じれば痕跡ゼロ。
- 使い捨てWSLディストロ（`wsl --import` → 使用後 `wsl --unregister`）。

### サンドボックスの限界（重要な注意）

- サンドボックス自体の脆弱性を突かれれば脱出されうる。「絶対安全」ではなく多層防御の1枚。
- **ネットワークを許可したまま**サンドボックス実行すると、ファイルシステム隔離だけでは
  インストーラの外部通信（トークン送信等）までは防げない。ネットワークもallowlist化するのが理想。
- 時限発動・環境検知型のコードはサンドボックス内では大人しく振る舞うことがある。

## macOS でのおすすめ: `srt` (@anthropic-ai/sandbox-runtime)

理由:
- **シンプル**: `npm install -g @anthropic-ai/sandbox-runtime` → `srt "<command>"` の
  1コマンドで完結。設定ファイル不要でも動く。
- **まさに用途が一致**: README に `curl | sh` インストーラのサンドボックス例が
  そのまま載っている。汎用サンドボックスではなく、この用途を明示的にサポート。
- **デフォルトが安全側**: 書き込み全拒否・ネットワーク全拒否がデフォルトで、
  必要なドメイン/パスだけ `~/.srt-settings.json` で明示的に許可する形。
- **macOS ネイティブ**: 追加依存なしで `sandbox-exec` (Seatbelt) を使う。bui は
  bubblewrap 依存のため Linux 専用（README でも macOS 非対応・代替として
  Sandbox.app や Docker Desktop を挙げている）。sandvault は永続エージェント
  セッション向けで単発インストーラには過剰。

```sh
npm install -g @anthropic-ai/sandbox-runtime
srt "curl -fsSL https://mise.run | sh"
```

インストーラがネットワーク上の別ホスト（GitHub Releases 等)からバイナリを
落とす場合は、`~/.srt-settings.json` の `network.allowedDomains` にそのドメインを
足す必要がある（デフォルトはネットワーク全拒否のため）。

## Deno のサンドボックス機能について

Deno には `--allow-net` / `--allow-read` / `--allow-write` / `--allow-run` などの
パーミッションベースのセキュリティモデルがある。ただしこれは **Deno ランタイム上で
実行される JS/TS コードそのものの capability を制限する仕組み**であり、
`curl | bash` のような POSIX シェルスクリプトには適用されない。

`--allow-run` は「Denoプロセスが子プロセスを起動できるかどうか」を許可するだけで、
起動された子プロセス（例: bash）はDenoのサンドボックス外＝通常のOS権限で動く。
つまり Deno を挟んでも `curl | sh` 自体は一切保護されない。既存のシェルインストーラを
Denoでサンドボックスしたい場合は無関係で、上記の `srt` / bui / sandbox-exec のような
OSレベルのサンドボックスツールを使う必要がある。
