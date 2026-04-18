# Setup

## Mac
### 初期設定
- [ ] XCode CLIのインストール
  ```sh
  xcode-select --install
  ```

- [ ] chezmoiの実行
  ```sh
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ryo246912
  ```


- [ ] miseの実行
  - [ ] ghコマンドのインストール
    ```sh
    brew install gh
    ```
  - [ ] ghコマンドのログイン
    ```sh
    gh auth login --scopes 'project'
    ```
  - [ ] GITHUB_TOKENを環境変数に設定
    ```sh
    export GITHUB_TOKEN=$(gh auth token)
    ```
  - [ ] 検証ツールのインストール
    ```sh
    mise install --jobs=1 cosign slsa-verifier
    ```
  - [ ] ランタイムのインストール
    ```sh
    mise install --jobs=1 node python rust
    ```
  - [ ] 他ツールのインストール
    ```sh
    mise install --jobs=2
    ```

- [ ] karabiner-elements
  - [ ] 「Default」というProfile名を作成 or リネーム
  - [ ] `karabiner.ts`を実行
    ```sh
    mise run karabiner-apply
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

#### クラウドストレージの設定
- [ ] Google Drive のインストール
  ```powershell
  winget install --id Google.GoogleDrive -e
  ```
- [ ] Obsidian と Google Drive の同期設定
  ```powershell
  winget install Anthropic.Claude
  ```

#### その他アプリケーション
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
  - [ ] [ghコマンドのインストール](https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian)
  - [ ] ghコマンドのログイン
    ```sh
    gh auth login --scopes 'project'
    ```
  - [ ] GITHUB_TOKENを環境変数に設定
    ```sh
    export GITHUB_TOKEN=$(gh auth token)
    ```
  - [ ] 検証ツールのインストール
    ```sh
    mise install --jobs=1 cosign slsa-verifier
    ```
  - [ ] ランタイムのインストール
    ```sh
    mise install --jobs=1 node python rust
    ```
  - [ ] 他ツールのインストール
    ```sh
    mise install --jobs=2
    ```
