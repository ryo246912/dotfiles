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
     sh ./not_config/script/setup_git_gpg.sh
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
