# Setup

## Mac

### 初期設定

- [ ] chezmoiの実行
  - `--use-builtin-git=on` で clone するため、事前の `xcode-select --install`（system git）は不要
  - Command Line Tools は直後の Homebrew インストーラが自動導入する

  ```sh
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --use-builtin-git=on ryo246912
  ```

- [ ] miseの実行（上の `chezmoi init --apply` の post-apply hook が自動実行する）
  - hook が順に実行する:
    1. `MISE_ENV=mac mise bootstrap packages apply`
    2. gh 導入（`mise install aqua:cli/cli`）→ 未ログインなら `gh auth login --scopes 'project'` のプロンプトが出るので対話でログイン
    3. `GITHUB_TOKEN=$(gh auth token) mise install`
  - 失敗時は `chezmoi apply` で再試行
  - **brew で個別導入済みのパッケージがあると bootstrap が失敗する場合がある**（旧来のセットアップから
    移行してきた環境や、`dot_config/mise/config.mac.toml` の `[bootstrap.packages]` に無い formula の
    依存として過去に入っていた場合など）。`mise bootstrap packages apply` は宣言した brew パッケージの
    導入・リンクを mise 管理下で行うが、対象パスに mise 管理外のファイルがすでに存在するとリンクを拒否
    して以下のように失敗する:
    ```
    mise ERROR cannot link xz: these files already exist and were not
     created by mise or brew:
      /opt/homebrew/bin/unxz
      ...
    Remove or rename them, then re-run `mise bootstrap packages apply`
    ```
    対応手順:
    1. エラーメッセージ冒頭に出ているパッケージ名（上記例では `xz`）を確認する
    2. 依存関係を無視してアンインストールする（他の formula の依存として入っている場合は
       `--ignore-dependencies` が必要）
       ```sh
       brew uninstall --ignore-dependencies xz
       ```
    3. 再度 bootstrap を実行する（mise 管理下でクリーンに再導入・リンクされる）
       ```sh
       MISE_ENV=mac mise bootstrap packages apply
       ```
    4. 別のパッケージで同様のエラーが出た場合は 1〜3 を繰り返す

    エラーメッセージが指す各ファイルを直接 `rm` して解決することもできるが、消し残しが出やすいので
    `brew uninstall` でパッケージごと外す方が確実。openssl@3 / ca-certificates / json-c のような
    共有依存まで巻き込む場合は、後述の[「real brew から mise bootstrap への本格移行」](#real-brew-から-mise-bootstrap-への本格移行共有依存の衝突対応)を参照。

- [ ] karabiner-elements
  - [ ] 「Default」というProfile名を作成 or リネーム
  - [ ] `karabiner.ts`を実行
    ```sh
    mise run karabiner:apply
    ```

- [ ] Clibor
  - [ ] 定型文を設定

- [ ] Browser
  - [ ] Vimium
    - [ ] 設定で`Vimium Options.json`をインポート
  - [ ] Tab Position Options

- [ ] Raycast
  - [ ] `Raycast.rayconfig`をインポート

- [ ] Google日本語入力
  - [ ] 「システム設定」で「キーボード」→「入力ソース」左下の「+」ボタンをクリックして、「日本語」を追加

- [ ] システム設定
  - [ ] トラックパッド
    - [ ] 「システム設定」→「トラックパッド」→「スクロールとズーム」→「ナチュラルなスクロール」をOFFにする
  - [ ] キーボード
    - [ ] 「システム設定」→「キーボード」→「キーのリピート速度」を「速い」にする
    - [ ] 「システム設定」→「キーボード」→「リピート入力認識までの時間」を「短い」にする
  - [ ] キーボードショートカット
    - [ ] 「通知センターの表示」
    - [ ] ファンクションキーとして使用するをONにする
    - [ ] 不要なショートカットはOFFにする

- [ ] VSCode
  - [ ] settings syncの同期
  - [ ] 設定ファイルをコピー

### real brew から mise bootstrap への本格移行（共有依存の衝突対応）

mise brew も real brew も同じ `/opt/homebrew` prefix を使う。`config.mac.toml` の
`[bootstrap.packages]` に列挙した formula を real brew 側でも個別に入れっぱなしにしていると、
`openssl@3` / `ca-certificates` / `json-c` のような共有依存を real brew が掴んだままになり、
mise 側がリンクできず前述の `cannot link` エラーになる。real brew 中心の環境から mise bootstrap
管理へ本格的に切り替える場合は、以下の手順で real brew 側から該当 formula と共有依存を退避させて
から bootstrap を実行する。

#### Phase 1. ブロッカー・移行対象を real brew から抜く

```sh
# 1) ブロッカーになりがちな formula を先に削除
#    （cocoapods は ruby gem を、ttyd は libwebsockets/libevent を道連れにする）
brew uninstall cocoapods ttyd

# 2) mise(brew:) に持たせる formula を real brew から外す
#    ＝ config.mac.toml の [bootstrap.packages] と同じ顔ぶれ
brew uninstall git gnupg tig colordiff tree ffmpeg goaccess ugrep \
  coreutils findutils gnu-sed grep blueutil pinentry-mac silicon

# 3) 孤立した共有依存を一掃（openssl@3 / ca-certificates / json-c / gettext / glib / cairo など）
brew autoremove
```

- `brew uninstall` で `... is required by <X>` と出たら、`<X>` が「まだ real brew に残す何か」
  なのでメモしておく（後続の判定に使う）
- `brew autoremove` が `openssl@3` / `ca-certificates` / `json-c` を削除できた場合、それは
  cocoapods / ttyd（と移行対象 formula）を抜いたことでこれらの共有依存が誰からも参照されない
  孤立状態になった、という意味。つまりそれらが真のブロッカーだったということ。

#### Phase 2. 受け入れテスト（ここが成否の分かれ目）

```sh
brew uses --installed ca-certificates
brew uses --installed json-c
brew uses --installed openssl@3      # ← ca-certificates を間接的に掴む全 formula
brew list --formula                  # real brew に残った formula 一覧
```

判定:

- 上記 3 つの `brew uses` がすべて空（誰も掴んでいない）→ mise brew が `ca-certificates` /
  `json-c` / `openssl@3` を link できる状態。Phase 3 へ進む
- 何か残っていたら、その名前が真のブロッカー。よくある例:
  - `ruby`（明示 install していると cocoapods 削除後も残る）→ `brew uninstall ruby` して
    mise の `core:ruby` か MacPorts へ逃がす
  - `mise`（`dot_config/brew/brew.json` 経由。brew 版 mise が `openssl@3` を掴んでいる場合）→
    mise 自体を brew ではなく標準インストーラに切り替える
  - それ以外の formula が残る場合は formula 単位で「MacPorts/mise へ逃がす」か「real brew
    併存に戻す」かを判断する
- `brew list --formula` は理想的には空（+ cask のみ残る）。cask は `brew uses` に出てこない
  ＝共有依存を掴んでいないので、そのまま real brew 管理で共存して問題ない

後始末（★ここを飛ばすと bootstrap で再度 `cannot link` になる）:

```sh
# 古い openssl@3 の残骸を消す（autoremove は最新版しか消さない）
brew uninstall --force openssl@3
brew cleanup

# 残った設定ファイルを消す（これが最重要）
rm -rf /opt/homebrew/etc/openssl@3 /opt/homebrew/etc/ca-certificates
```

`/opt/homebrew/etc/ca-certificates/cert.pem` や `openssl@3/*` の設定ファイルが残っていると、
mise brew が自前の `ca-certificates` / `openssl@3` を導入して `cert.pem` を link しようとした際に
「file exists」で再び `cannot link` になる（本移行手順で最初に踏みやすいエラー再発ポイント）。

#### Phase 3. mise brew で入れ直して確認

```sh
# dotfiles を最新化してから
chezmoi update    # or: git -C ~/.local/share/chezmoi pull && chezmoi apply
```

`chezmoi apply` の post-apply フックが `MISE_ENV=mac mise bootstrap packages apply --yes` →
`mise install` を自動実行する。手動なら:

```sh
MISE_ENV=mac mise bootstrap packages apply --yes
mise install --jobs=2
```

導入確認:

```sh
mise ls | grep -E 'silicon|tig|colordiff'   # mise 管理下に入ったか
type -a git tig silicon gnupg               # パスが mise/brew prefix を指すか
tig --version && silicon --version          # 実際に動くか
```

#### 注意点（共有 prefix の宿命）

mise brew も real brew も同じ `/opt/homebrew` prefix を使うため、Phase 2 でブロッカーを抜けても、
その後 real brew 側で `brew upgrade` / `brew doctor` / `brew cleanup` を走らせると、mise が張った
リンクを「見知らぬリンク」とみなして触ってしまう可能性がある。real brew は cask（GUI アプリ）用途
に限定して使い、`brew cleanup` は慎重に実行すること。

### 追加設定

- [ ] システム設定
  - [ ] 指紋認証
    - [ ] 「TouchIDとパスワード」→指紋追加
  - [ ] Dock
    - [ ] 「システム設定」→「Dockとメニューバー」→「Dockを自動的に隠す」をONにする
    - [ ] Dockの整理
  - [ ] トラックパッド
    - [ ] 不要な設定はOFFにする
  - [ ] ユーザとグループ
    - [ ] アイコン写真を設定
  - [ ] コントロールセンター
    - [ ] 「バッテリー」→「割合を表示」
  - [ ] 壁紙

- [ ] atuin
  - [ ] atuin login
    - atuin keyの内容を入力
  - [ ] atuin sync
  - [ ] atuin historyをzsh_historyに反映
    ```sh
    atuin history list --reverse --format "{command}" | uniq > ~/.local/state/zsh/restore_zsh_history
    cat ~/.local/state/zsh/.zsh_history >> ~/.local/state/zsh/restore_zsh_history
    mv ~/.local/state/zsh/restore_zsh_history ~/.local/state/zsh/.zsh_history
    ```
- [ ] git
  - [ ] 秘密鍵の設定
    - 既存の秘密鍵を使用する場合は、以下のコマンドを実行
      export済みの`secret_key.asc`を`.gnupg`にコピーしてきて、importする

    ```sh
    gpg --import ~/.gnupg/secret_key.asc
    ```

    もし再度exportしたい場合は、以下のコマンドを実行

    ```sh
    gpg --export-secret-keys --armor <fingerprint> > ~/.secret_key.asc
    ```

    - fingerprintは、以下のコマンドの`YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY`の内容

    ```sh
    gpg --list-secret-keys --keyid-format LONG
    # ----------------------------------
    # sec   rsa4096/XXXXXXXXXXXXXXXX  2023-01-01 [SC]
    #       YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
    # uid                 [ultimate] Your Name <your.email@example.com>
    # ssb   rsa4096/ZZZZZZZZZZZZZZZZ  2023-01-01 [E]
    ```
    - パスフレーズは、パスワードマネージャーに保存しているものを参照

    - 新規に秘密鍵を作成する場合は、以下のコマンドを実行
      - 基本そのままEnterを押していく
      - 名前・メールアドレスは、gitの設定と同じものを使用

    ```sh
    gpg --full-generate-key
    ```

    - 作成後、以下のコマンドでfingerprintを確認
      - GPG_KEY_IDの内容をgitconfigに設定する

    ```sh
    gpg --list-secret-keys --keyid-format LONG
    ```

    - (新しいメールアドレスを紐づける場合)GPGキーにメールアドレスを追加

      ```sh
      gpg --edit-key XXXXXXXXXXXXXXXX
      ```

      - adduidで編集、以下を入力して新しいメールアドレスを追加
        - Real name: 登録したい名前
        - Email address: 登録したいメールアドレス
        - Comment: コメント（任意）

      ```sh
      gpg> adduid
      ```

    - 登録済みのGPGキーを削除後、GitHubに新しいGPGキーを登録

    ```sh
    gh gpg-key delete $(gh gpg-key list | awk '{print $3}')
    ```

    ```sh
    gpg --armor --export XXXXXXXXXXXXXXXX | gh gpg-key add
    ```

  - [ ] gpg_agent・gitの設定
    ```
    setup-git-gpg
    ```
  - [ ] [sshの設定](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key)
    - 秘密鍵の生成
      1. ssh-keygenで生成→登録

      ```sh
      ssh-keygen -t ed25519 -C "<mail_address>"
      ```

      - パスフレーズを入力
      - Githubに公開鍵を登録

      ```sh
      gh ssh-key add ~/.ssh/id_ed25519.pub -t <title>
      ```

      2. ghコマンドで生成→登録
      - sshを選択

      ```sh
      gh auth login
      ```

      - 途中の画面で新しいキーを生成する→ghコマンドが自動で公開鍵をGitHubに登録

      ```
      ? Generate a new SSH key to add to your GitHub account? (Y/n) Y
      ? Enter a passphrase for your new SSH key (Optional)
      ? Title for your SSH key: (GitHub CLI)
      ```

    - ssh-agentにsshキーを追加

    ```sh
    eval "$(ssh-agent -s)"
    ```

    ```sh
    touch ~/.ssh/config
    ```

    ```sh
    cat << EOF >> ~/.ssh/config
    Host github.com
      AddKeysToAgent yes
      UseKeychain yes
      IdentityFile ~/.ssh/id_ed25519
    EOF
    ```

    ```sh
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    ```

- [ ] sshの設定(オプション)
  - 秘密鍵を共有してもらって保存

  ```sh
  cat << EOF > ~/.ssh/xx.pem
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
  EOF
  ```

  - sshコマンド
    - サーバーの以下教えてもらう
      - port
      - host名 or ip
      - ユーザ名

    ```sh
    ssh -i ~/.ssh/xx.pem -p <port> <user>@<bastion_host>
    ```

    - 踏み台サーバ経由してのポートフォワーディング

    ```sh
    ssh -i ~/.ssh/xx.pem -p <port> -L <local_port>:<target_host>:<target_port> <user>@<bastion_host>
    ```

### カスタムアプリの作成手順

- 手順

1. **「スクリプトエディタ」**（Applications > Utilities > Script Editor.app）を起動
2. 新規書類でapplescriptを作成

```applescript
do shell script "/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=\"$HOME/Library/Application Support/Claude2\" > /dev/null 2>&1 &"
```

3. **保存設定**:
   - メニューの「ファイル」→「書き出し...」を選択
   - **ファイルフォーマット**: 「アプリケーション」を選択
   - **名前**: 「Claude-Sub.app」など任意の名前に設定
   - **場所**: 「アプリケーション」フォルダ等に保存

- [ ] chrome

```applescript
do shell script "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=9222 --user-data-dir=$HOME/chrome-profiles/profile3 > /dev/null 2>&1 &"
```

- [ ] Claude Desktop

```applescript
do shell script "/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=\"$HOME/Library/Application Support/Claude2\" > /dev/null 2>&1 &"
```

### プライベート設定

- [ ] thunderbird
  - [ ] アカウントの設定
  - [ ] アドオンの設定
- [ ] obsidian
  - [ ] google-driveの同期設定
- [ ] Browser
  - [ ] obsidian-web-clipperの設定をインポート・ショートカットキーの設定

## Windows

### 初期セットアップ

#### パッケージマネージャーのインストール

- [ ] Scoop のインストール
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
  Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
  ```

#### 基本ツールのインストール

- [ ] Git
  ```powershell
  scoop install git
  ```
- [ ] Firefox / Chrome
  ```powershell
  scoop bucket add extras
  scoop install firefox
  scoop install chrome
  ```
- [ ] その他ユーティリティ
  ```powershell
  scoop install bitwarden
  scoop install alacritty
  scoop install autohotkey
  scoop install powertoys
  ```

#### Windows PC設定

- [ ] トラックパッドの設定
  - [ ] スクロール方法を調整
- [ ] クリップボード履歴を有効化
  - [ ] 「Windows」+「V」で履歴共有を有効
- [ ] バッテリー残量表示
  - [ ] 「バッテリー表示」を％表示に変更
- [ ] バッテリー充電設定（Lenovo）
  - [ ] Lenovo Vantage を起動
  - [ ] 「デバイス設定」→「バッテリー充電しきい値 / 保守モード」から充電上限を設定

#### ブラウザの初期設定

- [ ] Firefox でログイン
  - [ ] Mozilla アカウントでログイン
  - [ ] Twitter Container を設定
- [ ] ブラウザの各種設定
  - [ ] 拡張機能のインストール
  - [ ] ホームページ設定

#### その他アプリケーション

- [ ] Google Drive のインストール
  ```powershell
  winget install --id Google.GoogleDrive -e
  ```
- [ ] ツール
  ```powershell
  winget install Anthropic.Claude
  ```
- [ ] Raycast のインストール
  ```powershell
  winget install --id 9PFXXSHC64H3 -e
  ```
- [ ] Thunderbird のセットアップ
  - [ ] プロファイルを前の PC からコピー
  - [ ] アドオンの再インストール
- [ ] MusicBee のセットアップ
  - [ ] MusicBee フォルダをコピー
  - [ ] MusicBee アプリをコピーまたはインストール
  - [ ] WiFi 接続を有効化
  - [ ] ファイアウォール設定で MusicBee を許可
    1. キーボードの「Windows キー + R」を押し、`control` と入力
    2. 「システムとセキュリティ」→「Windows Defender ファイアウォール」を選択
    3. 「Windows Defender ファイアウォールを介したアプリまたは機能を許可」をクリック
    4. 右上の「設定の変更」を押す
    5. リスト内の「MusicBee」の「プライベート」にチェックを入れる
- [ ] EAC をセットアップ
  - [ ] プロファイルをインストール
  - [ ] エンコーダーを設定

#### NAS の接続

- [ ] QNAP Finder Pro のインストール
  ```powershell
  winget install QNAP.QfinderPro
  ```
- [ ] NAS にアクセス
- [ ] ネットワークドライブを割り当て

#### WSL のインストール

- [ ] PowerShell を起動（管理者権限）
- [ ] 実行ポリシーを設定
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
  ```
- [ ] Ubuntu をインストール
  ```powershell
  wsl -d Ubuntu
  ```
- [ ] ユーザー名とパスワードを設定

- [ ] chezmoiの実行

  ```sh
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ryo246912
  ```

- [ ] miseの実行
  - hook が順に実行する:
    1. `MISE_ENV=linux mise bootstrap packages apply`（**sudo のパスワード入力が要るので対話端末で実行すること**）
    2. gh 導入（`mise install aqua:cli/cli`）→ 未ログインなら `gh auth login --scopes 'project'` のプロンプトが出るので対話でログイン
    3. `GITHUB_TOKEN=$(gh auth token) mise install`
  - 非対話端末で apt bootstrap が未適用の場合、hook は最初の bootstrap で `exit 1` して**初回 `chezmoi init --apply` 自体が失敗する**（gh/mise install も走らない）。対話端末で `chezmoi apply` を実行すること

- [ ] git-credential-manager (GCM) のセットアップ（GPG 鍵のインポート後に実行。詳細は
      [`docs/credentials.md`](./credentials.md) 参照）
  ```sh
  pass init "$(git config user.signingkey)"
  git-credential-manager configure
  ```
