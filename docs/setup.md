# Setup

## Mac

### 初期設定

- [ ] Command Line Tools（CLT）のインストール（未導入時のみ）
  - 未導入のまま `git clone` すると `xcode-select: note: No developer tools were found, requesting install.`
    と出てダイアログが開くだけで clone は失敗する。先に入れておき、ダイアログの「インストール」を押して
    完了まで待つ（`brew:felixkratz/formulae/borders` のソースビルドにも CLT が要る）
  - エラーメッセージ中の `sudo xcode-select --switch path/to/Xcode.app` は Xcode.app を別の場所に置いている場合の
    例示なので実行しない

  ```sh
  xcode-select --install
  xcode-select -p  # /Library/Developer/CommandLineTools と出れば OK
  ```

- [ ] mise本体のインストール（未導入時のみ）

  ```sh
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

- [ ] リポジトリの clone

  ```sh
  git clone https://github.com/ryo246912/dotfiles.git ~/dotfiles
  cd ~/dotfiles
  ```

- [ ] ホストのロール（`HOST_ENV`）を決める
  - `HOST_ENV`（例: `mac,work2`）はログインシェル起動時に `config/zsh/host-env.map` からホスト ID で引かれ、
    次の変数が導出される

    | 変数                    | 値                                                     | 用途                                                                 |
    | ----------------------- | ------------------------------------------------------ | -------------------------------------------------------------------- |
    | `MISE_ENV`              | `HOST_ENV` と同じ                                      | `~/.config/mise/` の `config.<os>.toml`・`config.<role>.toml` を読む |
    | `FNOX_PROFILE`          | work ロールのときだけ `work`                           | `config/fnox/config.work.toml` の `[profiles.work.*]`                |
    | `AGENTSVIEW_PG_MACHINE` | `,` を `-` にした値（`host-env.map` で引いたときのみ） | agentsview の machine 名（[docs/agentsview.md](./agentsview.md)）    |

  - ホスト ID を確認し、`host-env.map` に `<ホストID>=<os>,<role>` の行があるか見る
    （`<role>` は `config/mise/config.<role>.toml` がある名前）

    ```sh
    scutil --get LocalHostName # Linux/WSL は hostname -s
    ```

    - 既存の行に合わせる → ホスト ID を変える（下記）
    - 新しいホスト → `host-env.map` に行を追加する（コミットは git の設定の後）
    - ホスト ID を変えずに別の値で引く → `MISE_HOST_ID` を `/etc/zshenv` などで export する

  - ホスト ID の変え方（変えたら新しいターミナルで確認する）
    - macOS: 「システム設定」→「一般」→「共有」→「ローカルホスト名」か、次のコマンド（英数字と `-` のみ）

      ```sh
      sudo scutil --set LocalHostName ryo-mac-private
      sudo scutil --set ComputerName ryo-mac-private # 任意
      sudo scutil --set HostName ryo-mac-private     # 任意
      dscacheutil -flushcache
      ```

    - Linux: `sudo hostnamectl set-hostname <ホストID>`
    - WSL: 既定は Windows の PC 名。変えるときは `/etc/wsl.conf` に書き、PowerShell で `wsl --shutdown`

      ```ini
      [network]
      hostname = ryo-win
      ```

  - bootstrap 後の反映は後述の「`HOST_ENV` の反映と `mise bootstrap` の再実行」、
    一時的に別ロールを試す方法は [docs/shell.md](./shell.md) 参照

- [ ] mise bootstrap の実行
  - **最初に `[dotfiles]` だけを適用する**（`[bootstrap.packages]` は
    `config-mac/mise/config.mac.toml` という dotfile の中身なので、他のフェーズより
    先に一度実体化しておく必要がある。`mise bootstrap` 内の packages フェーズは
    プロセス起動時に読み込んだ config しか見ないため、同一プロセス内で
    dotfiles 配置 → packages フェーズの順に反映されることはない）:
    ```sh
    MISE_ENV=mac mise bootstrap dotfiles apply --yes
    mise trust ~/.config/mise/config.mac.toml
    ```
    初回（apm/rulesync が未導入）は、ファイル配置に続けて `[bootstrap.hooks.post-dotfiles]` が
    gh 導入（未ログインなら `gh auth login --scopes 'project'` のプロンプト）→ `GITHUB_TOKEN=$(gh auth token) mise install`
    → APM の user-scope dependencies・rulesync generate まで実行する（導入済みの環境ではスキップ）。
    既存環境で conflict が出たときだけ:
    ```sh
    MISE_ENV=mac mise bootstrap dotfiles apply --force --yes "~/.config" "~/.local" "~/.aws"
    ```
  - 続けて `mise bootstrap` 本体を実行する:
    1. `[bootstrap.packages]` の導入（brew/brew-cask）
    2. `[dotfiles]` の再適用（既に適用済みなので通常は no-op）
    3. `[bootstrap.hooks.pre-tools]`: gh 導入（`mise install aqua:cli/cli`）→ 未ログインなら `gh auth login --scopes 'project'` のプロンプトが出るので対話でログイン → `GITHUB_TOKEN=$(gh auth token) mise install`（初回の `dotfiles apply` で導入済みなら差分のみ）
    4. `[tools]` の導入（3 で完了しているため通常は即座に終わる）
    5. `[bootstrap.hooks.post-tools]`: APM の user-scope dependencies・rulesync generate を差分があるときだけ実行

    ```sh
    MISE_ENV=mac mise bootstrap
    ```

  - 失敗時は同じ2コマンドを再実行する（各フェーズは収束的なので再実行して安全）
  - `brew:borders` のソースビルドが `ld: ... tapi error: malformed file` /
    `unknown architecture arm64e.x1-macos` で失敗する場合は、CLT に OS より新しい（beta 版 CLT 由来の）
    SDK（例: `MacOSX27.0.sdk`）が残っていて、`xcrun` がそれを選ぶ一方で `ld` が古く読めないのが原因。
    `ls /Library/Developer/CommandLineTools/SDKs/` で確認し、OS に合う SDK を `SDKROOT` で明示して再実行する:
    ```sh
    SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX$(sw_vers -productVersion | cut -d. -f1).sdk MISE_ENV=mac mise bootstrap packages apply --yes
    ```
  - 2回目以降の `dotfiles apply` はファイルを配置するだけで、ツールは入らない（初回の自動 install は apm/rulesync が
    未導入のときだけ）。ツールだけ入れ直すときは tools ステップだけ実行する
    （`pre-tools` hook が gh のトークンを渡すので、素の `mise install` より rate limit に当たりにくい）

    ```sh
    mise bootstrap --only tools # HOST_ENV 反映前は MISE_ENV=mac を付ける（ロール別のツールは入らない）
    ```

- [ ] git（push は SSH、コミットは GPG 署名になるので、コミット・push の前に済ませる）
  - 鍵の登録・削除に使う gh の scope を足しておく（初回 bootstrap の `gh auth login` は `project` だけ）

    ```sh
    gh auth refresh --scopes write:public_key,read:gpg_key,write:gpg_key,admin:gpg_key
    ```

  - [ ] secret設定ファイルの作成
    - サンプルをコピーし、`machineId`を自分の値に編集する

    ```sh
    cp ~/dotfiles/config/git/config.secret.sample ~/.config/git/config.secret
    nvim ~/.config/git/config.secret
    ```

    - 仕事用の設定が必要な場合も、サンプルをコピーして`email`と`signingkey`を編集する

    ```sh
    cp ~/dotfiles/config/git/config.work.secret.sample ~/.config/git/config.work.secret
    nvim ~/.config/git/config.work.secret
    ```

    - work3 用の設定が必要な場合も、サンプルをコピーして`email`と`signingkey`を編集する

    ```sh
    cp ~/dotfiles/config/git/config.work3.secret.sample ~/.config/git/config.work3.secret
    nvim ~/.config/git/config.work3.secret
    ```

    - 各値の確認方法
      - `coderabbit.machineId`: CodeRabbit CLI が git config に書き込む値。既存マシンの値に揃えるか、
        新しいマシンでは CLI を一度実行して書き込まれた値を移す

        ```sh
        git config --show-origin --get coderabbit.machineId
        ```

      - `user.email`: GitHub の「Settings」→「Emails」で Verified の仕事用アドレス。
        GPG 鍵の UID にも同じアドレスが必要（下の「秘密鍵の設定」の `adduid`）
      - `user.signingkey`: 下の「秘密鍵の設定」の後に埋める。`sec rsa4096/XXXXXXXXXXXXXXXX` の `/` の後ろ
        （`gh gpg-key list` の 2 列目でも確認できる）

        ```sh
        gpg --list-secret-keys --keyid-format LONG "<メールアドレス>"
        ```

    - 編集後、設定ファイルが読み込まれていることを確認する

    ```sh
    git config --show-origin --get-regexp '^user\.(email|signingkey)$'
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
      gh ssh-key add ~/.ssh/id_ed25519.pub -t "<title>"
      ```

      2. ghコマンドで生成→登録
      - sshを選択（`gh auth login` はトークンを作り直して scope が初期化されるので、必要な scope を渡す）

      ```sh
      gh auth login --scopes project,write:public_key,read:gpg_key,write:gpg_key,admin:gpg_key
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

    macOS（`UseKeychain` と `--apple-use-keychain` は macOS 専用）:

    ```sh
    cat << EOF >> ~/.ssh/config
    Host github.com
      AddKeysToAgent yes
      UseKeychain yes
      IdentityFile ~/.ssh/id_ed25519
    EOF
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    ```

    Linux/WSL:

    ```sh
    cat << EOF >> ~/.ssh/config
    Host github.com
      AddKeysToAgent yes
      IdentityFile ~/.ssh/id_ed25519
    EOF
    ssh-add ~/.ssh/id_ed25519
    ```

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
    gh gpg-key list | cut -f2 | xargs -n1 gh gpg-key delete --yes
    ```

    ```sh
    gpg --armor --export XXXXXXXXXXXXXXXX | gh gpg-key add
    ```

  - [ ] gpg_agent・gitの設定
    ```
    setup-git-gpg
    ```
  - [ ] GPG署名の確認
    - ローカルでは、署名済みコミットを検証する

    ```sh
    git verify-commit HEAD
    ```

    - `Good signature`と表示されれば署名自体の検証は成功している
    - コミットのauthor・committerと、署名に使用したGPG鍵のUIDは別の情報である。`git verify-commit`が表示する名前とメールアドレスはGPG鍵のUIDであり、commit authorとの一致を検証しているわけではない
    - 自分の鍵に対する`This key is not certified with a trusted signature`という警告は、ローカルのGPGで所有者信頼度を設定していないという意味で、署名の失敗ではない
    - author・committerと署名をまとめて確認する場合は、以下を実行する

    ```sh
    git show --no-patch --show-signature --format=fuller HEAD
    ```

    - GitHub上の`Verified`判定はローカルの信頼度とは別である。PRを作成せずに確認する場合は、コミットをブランチへpushした後、GitHub APIで確認する

    ```sh
    git push origin HEAD
    gh api "repos/{owner}/{repo}/commits/$(git rev-parse HEAD)" \
      --jq '.commit.verification | {verified, reason, verified_at}'
    ```

    - `verified`が`true`ならGitHubでも署名が正しく認識されている
    - `false`の場合は、`reason`を確認し、公開鍵がGitHubアカウントに登録されているか、コミットのメールアドレスがGitHubアカウントと紐づいているかを確認する

- [ ] `HOST_ENV` の反映と `mise bootstrap` の再実行
  - 初回 bootstrap は `MISE_ENV=mac` だけで動くので、ロール別のツールや cask は入っていない。
    シェルを起動し直して確認し、もう一度実行する
  - 新しいターミナルを開くか、次で起動し直す（`exec $SHELL -l` だけでは引き継いだ `ZDOTDIR` のせいで
    `~/.zshenv` が読まれない。詳細は [docs/shell.md](./shell.md)）

    ```sh
    exec env -u ZDOTDIR -u HOST_ENV -u MISE_ENV -u FNOX_PROFILE -u AGENTSVIEW_PG_MACHINE zsh -l
    ```

    起動し直したシェルで:

    ```sh
    echo "HOST_ENV=$HOST_ENV MISE_ENV=$MISE_ENV FNOX_PROFILE=$FNOX_PROFILE"
    mise bootstrap
    ```

  - `host-env.map` を変えた場合はここでコミットして push する

- [ ] fnox: Bitwarden Secrets Manager の machine account を用意する
  - `config/fnox/config.toml` の `bws` provider は machine account の access token（`BWS_ACCESS_TOKEN`）で認証する。
    トークンは age で暗号化して `config/fnox/config.toml` に置いてあるので、machine account の作成は初回だけ、
    トークンの発行は初回と作り直すとき（期限切れ・漏洩時）だけでよい。2台目以降はどちらも行わず、
    新しい PC の age 公開鍵を `recipients` に追加し、既存の PC で `fnox reencrypt --provider age` を実行して
    `BWS_ACCESS_TOKEN` を再暗号化する（[docs/fnox.md の「複数 PC で使う場合」](./fnox.md#複数-pc-で使う場合2台目以降のセットアップ)）。
    以下の「初回・作り直し時のみ」の手順はスキップし、動作確認だけ行う
  - （初回・作り直し時のみ）Web 保管庫で machine account を追加し、access token を発行する
    （トークンの作り直し時は machine account は作り直さず、既存の machine account を開いて 4 だけ行う）
    1. [Web 保管庫](https://vault.bitwarden.com) にログインし、左上の製品切り替えで **Secrets Manager** を開く
       （Organization が必要。Password Manager との違いは [docs/bitwarden.md](./bitwarden.md)）
    2. 左メニューの **Machine accounts** →「**New machine account**」で名前（例: `dotfiles-fnox`）を入れて保存する
    3. 作成した machine account を開き、**Projects** タブで `config/fnox/config.toml` の
       `[providers.bws].project_id` の project を追加し、権限を **Can read** にする
       （project ID は **Projects** 一覧で project を開いた URL か設定画面で確認できる）
    4. **Access tokens** タブ →「**Create access token**」で名前と有効期限（無期限も可）を決めて作成し、
       表示されたトークンをコピーする（この画面を閉じると二度と表示されない）
  - （初回・作り直し時のみ）トークンを age で暗号化して git 管理下の設定に書き込む（hidden prompt に貼り付ける。
    コマンド引数に渡すと shell history や `ps` に残る）。age 鍵（`~/.config/fnox/age.txt`）と
    `recipients` が未設定なら先に [docs/fnox.md のセットアップ手順](./fnox.md#1-bitwarden-secrets-manager-bitwarden-sm-provider-bws) を行う

    ```sh
    FNOX_CONFIG_DIR="$HOME/dotfiles/config/fnox" fnox set --global --provider age BWS_ACCESS_TOKEN
    git -C ~/dotfiles diff config/fnox/config.toml  # BWS_ACCESS_TOKEN の行だけ変わっていることを確認
    mise bootstrap dotfiles apply
    ```

  - 動作確認してからコミットして push する。今のシェルには `BWS_ACCESS_TOKEN` が未設定（作り直したときは古い値）
    なので、age から復号した値を export してから bws の secret を読む（新しいシェルでは
    `config/zsh/lazy/mise.zsh` が自動で export する）

    ```sh
    export BWS_ACCESS_TOKEN="$(fnox get BWS_ACCESS_TOKEN)"
    fnox get CZ_OPENAI_API_KEY >/dev/null && echo ok  # bws から読めるか
    ```

  - トークンを作り直したときは、Web 保管庫の **Access tokens** タブで古いトークンを **Revoke** する

- [ ] （work ホストのみ）git 管理外の work 用ファイルを用意する
  - 雛形をコピーしてプレースホルダを書き換える（コピー先は gitignore 済みかリポジトリ外）。
    git の secret ファイルは上の「git」で用意済み

    | 用途                        | 雛形                                         | コピー先                                         | 対象             |
    | --------------------------- | -------------------------------------------- | ------------------------------------------------ | ---------------- |
    | AWS の SSO・aws-vault 設定  | `~/.aws/config.example`                      | `~/.aws/config`                                  | work2 / work3    |
    | sandbox の許可ドメイン      | `config/sbx/allow-domains.work3.txt.example` | `config/sbx/allow-domains.work3.txt`             | work3            |
    | sandbox から使う MCP サーバ | `config/sbx/mcp.<role>.yml.example`          | `config/sbx/mcp.<role>.yml`                      | work2 / work3    |
    | 仕事用の環境変数など        | なし                                         | `~/.zshrc.secret` / `~/.zprofile.secret`（任意） | 必要なホストのみ |

  - AWS: プロファイル名（`XXX`）・`sso_account_id`・`sso_start_url` を書き換える
    - `sso_start_url`: AWS access portal の URL（`https://xxx.awsapps.com/start`）。社内の案内か管理者から受け取る
    - `sso_account_id` / `sso_role_name`: access portal にログインすると一覧で出る（`aws configure sso` でも選べる）
    - プロファイル名: aws-vault・Terraform・`mcp.<role>.yml` の `--profile` と揃える

    ```sh
    cp ~/.aws/config.example ~/.aws/config
    nvim ~/.aws/config
    aws sso login --sso-session work
    aws-vault list
    ```

  - sandbox: `~/dotfiles/config/sbx/` に置き、編集後に登録し直す（[docs/docker-sandboxes.md](./docker-sandboxes.md)）

    work3:

    ```sh
    cd ~/dotfiles/config/sbx
    cp allow-domains.work3.txt.example allow-domains.work3.txt
    cp mcp.work3.yml.example mcp.work3.yml
    nvim allow-domains.work3.txt mcp.work3.yml
    mise run sandbox:setup
    mise run sandbox:mcp-add
    ```

    work2（MCP だけ。許可ドメインを足すなら `allow-domains.work2.txt` を作り、`sandbox:setup` も実行する）:

    ```sh
    cd ~/dotfiles/config/sbx
    cp mcp.work2.yml.example mcp.work2.yml
    nvim mcp.work2.yml
    mise run sandbox:mcp-add
    ```

    - `allow-domains.*.txt`: `sbx policy log <sandbox>` でブロックされたドメインを見て足す
    - `mcp.<role>.yml` の `xxx`: AWS のプロファイル名、work3 リポジトリのパス、社内サービスの URL

  - `~/.zshrc.secret` / `~/.zprofile.secret`: 雛形なし。リポジトリに置けないトークンや環境変数を書く（zsh 起動時に読まれる）

- [ ] （任意）`~/.config` の track mode 履歴を他マシンと同期する

  ```sh
  mise bootstrap dotfiles origin set https://github.com/ryo246912/dotfiles-history.git
  ```

- [ ] macOS defaults の適用

  ```sh
  MISE_ENV=mac mise bootstrap macos defaults apply
  ```

- [ ] mac 個別セットアップ（sudo のパスワード入力・Rosetta の同意を求められるので対話端末で実行する。
      `bootstrap:mac-brew`/`bootstrap:mac-packages` は `raw = true` で TTY を受け取る）

  ```sh
  mise run bootstrap:mac
  ```

- [ ] karabiner-elements
  - [ ] 「Default profile」というProfileがあることを確認（Karabiner-Elements の初回起動時に自動で作られる既定名。無ければ作成 or リネーム）
  - [ ] `karabiner.ts`を実行
    ```sh
    mise run karabiner:apply
    ```

- [ ] Rectangle
  - [ ] Rectangle を起動し、アクセシビリティの許可を求められたら「システム設定」→「プライバシーとセキュリティ」→
        「アクセシビリティ」で Rectangle を ON にする
  - [ ] 設定ファイルをインポートする
    - メニューバーの Rectangle アイコン →「設定...」→「一般」タブ下部の「インポート」から
      `~/dotfiles/unmanaged/rectangle/RectangleConfig.json` を選択する
    - Finder のファイル選択ダイアログで `⇧⌘G` を押してパスを直接入力すると早い
    - 設定を変えたら同じ画面の「エクスポート」で上記ファイルに上書きし、コミットする

- [ ] Browser
  - [ ] Vimium
    - [ ] 設定で`Vimium Options.json`をインポート
  - [ ] Tab Position Options
  - [ ] Link to Text Fragment
  - [ ] DeepL
  - [ ] Obsidian Web Clipper
    - [ ] 設定をインポート・ショートカットキーの設定

- [ ] Google日本語入力
  - [ ] 「システム設定」で「キーボード」→「入力ソース」左下の「+」ボタンをクリックして、「日本語」を追加

- [ ] システム設定
  - [ ] キーボードショートカット
    - [ ] option+tabでアプリ切替・ctrl+downで通知センター表示を設定
      ```sh
      mise run bootstrap:mac-hotkeys
      ```
    - [ ] ファンクションキーとして使用するをONにする
    - [ ] 以下の項目だけをONにし、それ以外のショートカットはすべてOFFにする
          （「システム設定」→「キーボード」→「キーボードショートカット...」）
      - Mission Control
        - 通知センターを表示（`^↓`。`bootstrap:mac-hotkeys` で設定済み）
      - キーボード
        - メニューバーを操作対象にする（`^F2`）
        - Dockを操作対象にする（`^F3`）
        - ウインドウのツールバーを操作対象にする（`^F5`）
        - 次のウインドウを操作対象にする（`⌥⇥`。`bootstrap:mac-hotkeys` で設定済み）
      - スクリーンショット（5項目すべて）
        - 画面のピクチャをファイルとして保存（`⇧⌘3`）
        - 画面のピクチャをクリップボードにコピー（`^⇧⌘3`）
        - 選択部分のピクチャをファイルとして保存（`⇧⌘4`）
        - 選択部分のピクチャをクリップボードにコピー（`^⇧⌘4`）
        - スクリーンショットと収録のオプション（`⇧⌘5`）

- [ ] VSCode
  - [ ] settings syncの同期
  - [ ] 設定ファイルをコピー

### 追加設定

- [ ] システム設定
  - [ ] 指紋認証
    - [ ] 「TouchIDとパスワード」→指紋追加
  - [ ] Dock
    - 自動的に隠す設定と並び順は `config-mac/mise/config.mac.toml` の `[bootstrap.macos.dock]` で管理している
    - [ ] 適用して Dock を再起動する

      ```sh
      mise bootstrap macos defaults apply && killall Dock
      ```
  - [ ] トラックパッド
    - [ ] 不要な設定はOFFにする
  - [ ] ユーザとグループ
    - [ ] アイコン写真を設定
  - [ ] コントロールセンター
    - [ ] 「バッテリー」→「割合を表示」
  - [ ] 壁紙
  - [ ] フルディスクアクセス（ターミナルアプリ）
    - Downloads・Desktop・Documents などは macOS のプライバシー保護（TCC）により、許可されたアプリからしか読めない（yazi 等で中身が見えない原因）
    - [ ] 「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」を開く

      ```sh
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
      ```

    - [ ] 左下の「＋」から使用するターミナルアプリを追加してONにする
      - `/Applications/Ghostty.app`
    - [ ] 追加したターミナルアプリを再起動する

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

- [ ] claude（work3用の追加アカウント）
  - `~/.claude-work3`を作成し、`~/.claude`配下の`projects`/`settings.json`/`agents`/`skills`/`plugins`を（未作成なら）シンボリックリンクで共有する（devcontainerのpost-createでも同じsymlinkを作るので、一度devcontainerを起動していれば不要。詳細は[`docs/ai.md`](ai.md)参照）

    ```sh
    mkdir -p ~/.claude-work3
    for entry in projects settings.json agents skills plugins; do
      [ -e ~/.claude-work3/"$entry" ] || [ -L ~/.claude-work3/"$entry" ] || ln -s ../.claude/"$entry" ~/.claude-work3/"$entry"
    done
    ```

  - 初回はアカウント未ログインの状態で起動するので、そのままプロンプトに従ってwork3用アカウントでログインする

    ```sh
    CLAUDE_CONFIG_DIR=~/.claude-work3 claude --dangerously-skip-permissions
    ```

- [ ] Vicinae の shortcuts / snippets（詳細は [`docs/raycast.md`](raycast.md)）
  - `templates/vicinae/*.json.tera` から `~/.local/share/vicinae/{shortcuts,snippets}/*.json` を生成する。
    メールアドレスや個人・仕事を特定できる URL は git 管理外の `templates/vicinae/vicinae.secret.yaml` に置く
  - [ ] 雛形をコピーする

    ```sh
    cd ~/dotfiles
    cp -n templates/vicinae/vicinae.secret.yaml.sample templates/vicinae/vicinae.secret.yaml
    ```

  - [ ] `vicinae.secret.yaml` に値を書く（その PC で使わない `vicinae_url_*`・`vicinae_email_other` は消すと、その項目は出ない）

    | キー                          | 使われる場所                       | 値                                            |
    | ----------------------------- | ---------------------------------- | --------------------------------------------- |
    | `vicinae_email_private`       | snippet `email(private)`（`,adp`） | 個人のメールアドレス                          |
    | `vicinae_email_work`          | snippet `email(work)`（`,adw`）    | 仕事のメールアドレス                          |
    | `vicinae_email_gmail`         | snippet `email(gmail)`（`,ado`）   | Gmail のアドレス                              |
    | `vicinae_email_other`         | snippet（`,ads`）                  | 名前も公開したくないアドレス                  |
    | `vicinae_name_email_other`    | 上の snippet の名前                | 省略すると `email(other)`                     |
    | `vicinae_url_amazon_wishlist` | shortcut `amazon`                  | Amazon の「ほしい物リスト」を開いたときの URL |
    | `vicinae_url_tabelog`         | shortcut `tabelog`                 | 食べログのマイページ →「保存したお店」の URL  |
    | `vicinae_name_work_repo`      | shortcut の名前                    | 仕事のリポジトリ名（省略すると `work repo`）  |
    | `vicinae_url_work_repo`       | shortcut（仕事のリポジトリ）       | 仕事のリポジトリの URL                        |

  - [ ] 既存の Vicinae に shortcuts / snippets があれば、テンプレートに無いもの（apply で上書きされて消えるもの）を
        確認し、必要ならテンプレートに枠を足す（確認コマンドは `docs/raycast.md`）
  - [ ] Vicinae を終了してから apply し、Vicinae を起動し直す（Vicinae は起動時にしか読まない）

    ```sh
    osascript -e 'tell application "Vicinae" to quit'
    mise run bootstrap:dotfiles:apply
    open -a Vicinae
    ```

  - [ ] snippet のキーワード（`,adp` など）でアドレスが展開されること、shortcut が出ることを確認する

- [ ] ccmanagerのプロジェクトルート作成
  - `CCMANAGER_MULTI_PROJECT_ROOT`（`config/zsh/lazy/private.zsh` / `workN.zsh`）が指す
    `~/Programming/<role>/worktrees` と、実体のリポジトリを置く`~/Programming/<role>/repos`は
    `[dotfiles]`の管理外のため、事前にディレクトリを作成する
  - work1/work2ロールは`~/work/worktrees`のまま（対象外）

    ```sh
    mkdir -p ~/Programming/repo/repos ~/Programming/repo/worktrees
    mkdir -p ~/Programming/work3/repos ~/Programming/work3/worktrees
    ```

- [ ] obsidian
  - [ ] syncthingの同期設定

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

- [ ] Claude Desktop（work3用）

```applescript
do shell script "/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=\"$HOME/Library/Application Support/ClaudeWork3\" > /dev/null 2>&1 &"
```

- 「保存設定」の手順は上記と同様（**名前**は「Claude-Work3.app」など任意の名前に設定）

- [ ] Markdownファイルのデフォルトアプリ設定
  - `mise bootstrap dotfiles apply`で`~/.local/bin/md-preview-launcher`を配置する
  - Automatorを起動し、「新規書類」→「アプリケーション」を選択する
  - 「シェルスクリプトを実行」をワークフローへ追加し、以下のように設定する
    - シェル: `/bin/zsh`
    - 入力の引き渡し方法: 「引数として」
    - スクリプト:

      ```sh
      "$HOME/.local/bin/md-preview-launcher" "$@"
      ```

  - `md-preview-launcher.app`という名前で`~/Applications`へ保存する
  - Finderで任意の`.md`ファイルを選択し、`Command + I`（「情報を見る」）を開く
  - 「このアプリケーションで開く」から`md-preview-launcher`を選択する
  - 「すべてを変更...」をクリックし、確認ダイアログで「続ける」を選択する

### プライベート設定

- [ ] thunderbird
  - [ ] アカウントの設定
  - [ ] アドオンの設定

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

- [ ] mise本体のインストール（未導入時のみ）

  ```sh
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

- [ ] リポジトリの clone

  ```sh
  git clone https://github.com/ryo246912/dotfiles.git ~/dotfiles
  cd ~/dotfiles
  ```

  明示的な `mise trust` は不要。直後の `mise bootstrap dotfiles apply --yes`
  （後述）の `--yes` 自体が、未trustの `mise.toml` をそのまま自動trustし、
  `~/.local/state/mise/trusted-configs/` にtrust状態を永続化する（実機確認済み:
  trustなしの状態から `mise bootstrap dotfiles apply --yes` を直接実行しても
  成功し、以後 `--yes` を付けずに呼んでもtrustエラーが出ない）。
  `config/mise/config.toml` 側で宣言している `trusted_config_paths` は、
  （dotfiles配置後に）この trust 状態を明示的な設定としても持たせるためのもので、
  初回セットアップの成立自体には不要。
  直後の `mise` は `mise.run` インストーラで入れた最新版なので、`min_version` の
  更新は初回は不要（`mise bootstrap` は config を読む際に `min_version` 未満だと
  実行を拒否するが、新規インストール直後は常に満たしている）。2回目以降、
  リポジトリ側で `min_version` が上がった場合は、後述の `mise bootstrap` 完了後に
  `lefthook.yml` の `post-merge` フックが `git pull` のたびに自動で self-update する。

- [ ] mise bootstrap の実行（**sudo のパスワード入力が要るので対話端末で実行すること**。
      **必ず `MISE_ENV=linux` を明示する**。
      `HOST_ENV`・git・bootstrap の再実行は Mac 側の同名の項目参照（ホスト ID は `hostname -s`）。
      `[dotfiles]`・`[bootstrap.hooks.*]` は `~/dotfiles` の `mise.toml`/`mise.linux.toml`
      自身が持つため、必ず `~/dotfiles` 直下で実行する）
  - **最初に `[dotfiles]` だけを適用する**（apt 用の `[bootstrap.packages]` は
    `config/mise/config.linux.toml` という dotfile の中身なので、他のフェーズより
    先に一度実体化しておく必要がある。packages フェーズは `mise bootstrap`
    プロセス起動時に読み込んだ config しか見ないため、同一プロセス内で
    dotfiles 配置 → packages フェーズの順に反映されることはない）:
    ```sh
    MISE_ENV=linux mise bootstrap dotfiles apply --yes
    mise trust ~/.config/mise/config.linux.toml
    ```
    初回（apm/rulesync が未導入）は、ファイル配置に続けて `[bootstrap.hooks.post-dotfiles]` が
    gh 導入（未ログインなら `gh auth login --scopes 'project'` のプロンプト）→ `GITHUB_TOKEN=$(gh auth token) mise install`
    → APM の user-scope dependencies・rulesync generate まで実行する（導入済みの環境ではスキップ）。
    このコマンドで `config/` 等の各ファイルへのシンボリックリンクが `~/.config` に張られる
    （`~/.config` は symlink-each と track の両方で宣言している。詳細は [docs/mise.md](./mise.md) の
    track/history の節参照）。
    既存環境を更新する場合、以前 `copy` で配っていた `~/.config`・`~/.local` や、chezmoi 時代の
    `~/.aws/config.example` に実ファイルが残っていると conflict で止まる。その場合は一度だけ
    force が必要。target を並べてこの3エントリだけに force を閉じる（他エントリのライブ編集を
    巻き込まないため）:
    ```sh
    MISE_ENV=linux mise bootstrap dotfiles apply --force --yes "~/.config" "~/.local" "~/.aws"
    ```
    force は実ファイルをリンクで置き換えるので、**先に配置先だけにある編集を取り込む**こと
    （確認のしかたと注意点は [docs/mise.md](./mise.md) の
    「target → source の逆方向ワークフロー」参照）。`MISE_ENV` を省くと
    `mise.mac.toml`/`mise.linux.toml` の OS 別 exclude が読まれず、他 OS 向けのファイルまで
    リンクしてしまうので、ここでも明示する（1つ上のコマンドと同じ理由）。
  - 続けて `mise bootstrap` 本体を実行する。今度は packages フェーズが上で配置した
    `~/.config/mise/config.linux.toml` を正しく読める:
    1. `[bootstrap.packages]` の導入（apt。sudo プロンプトが出る）
    2. `[dotfiles]` の再適用（既に適用済みなので通常は no-op）
    3. `[bootstrap.hooks.pre-tools]`: gh 導入（`mise install aqua:cli/cli`）→ 未ログインなら `gh auth login --scopes 'project'` のプロンプトが出るので対話でログイン → `GITHUB_TOKEN=$(gh auth token) mise install`（初回の `dotfiles apply` で導入済みなら差分のみ）
    4. `[bootstrap.hooks.post-tools]`: APM の user-scope dependencies・rulesync generate を差分があるときだけ実行

    ```sh
    MISE_ENV=linux mise bootstrap
    ```

  - 元の chezmoi hook にあった「非対話端末なら apt bootstrap で中断する」ガードは
    native の packages フェーズには無いため、非対話端末（cron 等）から実行すると sudo
    プロンプトでハングしうる。対話端末（TTY）から実行すること
  - 失敗時は同じ2コマンドを再実行する（各フェーズは収束的なので再実行して安全）
  - 2回目以降の `dotfiles apply` だけではツールは入らない（初回の自動 install は apm/rulesync が未導入のときだけ）。
    ツールだけ入れ直すときは `mise bootstrap --only tools`
    （`HOST_ENV` 反映前は `MISE_ENV=linux` を付ける。ロール別のツールは入らない）

- [ ] （任意）`~/.config` の track mode 履歴を他マシンと同期する（Mac 側の同項目参照）

- [ ] git-credential-manager (GCM) のセットアップ（GPG 鍵のインポート後に実行。詳細は
      [`docs/credentials.md`](./credentials.md) 参照）
  ```sh
  pass init "$(git config user.signingkey)"
  git-credential-manager configure
  ```
