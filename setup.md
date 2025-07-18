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
  - [ ] ランタイムのインストール
    ```sh
    mise install --jobs=1 node python rust
    ```
  - [ ] 他ツールのインストール
    ```sh
    mise install --jobs=1
    ```

- [ ] karabiner-elements
  - [ ] 「Default」というProfile名を作成 or リネーム
  - [ ] `goku`を実行
    ```sh
    goku
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
  - [ ] gpg_agent・gitの設定
     ```
     sh ./not_config/script/setup_git_gpg.sh
     ```

### プライベート設定
- [ ] thunderbird
  - [ ] アカウントの設定
  - [ ] アドオンの設定
- [ ] obsidian
  - [ ] google-driveの同期設定
- [ ] Browser
  - [ ] obsidian-web-clipperの設定をインポート・ショートカットキーの設定
