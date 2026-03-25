# DOTFILE-58: devcontainerからgit push出来るように設定する

## 目的とスコープ

devcontainerからセキュアに `git push` → PR作成ができるよう、devcontainerの設定を修正する。
SSH鍵を使わず、既存の `GH_TOKEN` 環境変数を活用したHTTPS認証方式に統一する。

---

## 根本原因分析

### 問題1: `.gitconfig` が読み取り専用でマウントされている

```json
"type=bind,source=${localEnv:HOME}/.config/git/config,target=/home/vscode/.gitconfig,readonly"
```

`/home/vscode/.gitconfig` が readonly のバインドマウントのため、`gh auth setup-git` や `git config` が書き込めず以下エラーが発生する：

```
error: could not write config file /home/vscode/.gitconfig: Device or resource busy
```

### 問題2: GitHub向けSSH認証が機能しない

`gh auth status` の出力では `Git operations protocol: ssh` となっているが、コンテナ内にGitHub登録済みのSSH鍵がない。
マウントされている `id_docker_devcontainer`（→ `id_ed25519`）はホスト通知用であり、GitHubには登録されていない。

---

## 実装方針

### アプローチ: `.gitconfig` マウント先を変更 + post-create で書き込み可能な gitconfig を生成

**セキュリティ方針:**
- ホストの `.gitconfig` は変更しない（読み取り専用を維持）
- `GH_TOKEN` を使ったHTTPS認証（SSH鍵不要）
- コンテナ内のみ有効な設定

### 変更対象ファイル

#### 1. `dot_config/devcontainer/devcontainer.json`

`.gitconfig` マウントのターゲットを変更:

```diff
- "type=bind,source=${localEnv:HOME}/.config/git/config,target=/home/vscode/.gitconfig,readonly",
+ "type=bind,source=${localEnv:HOME}/.config/git/config,target=/tmp/gitconfig-host,readonly",
```

#### 2. `dot_config/devcontainer/scripts/executable_post-create.sh`

コンテナ用の書き込み可能な `~/.gitconfig` を生成する処理を追加:

```bash
# コンテナ用の書き込み可能な .gitconfig を生成
if [ ! -f ~/.gitconfig ]; then
    cat > ~/.gitconfig << 'EOF'
[include]
    path = /tmp/gitconfig-host
[credential "https://github.com"]
    helper = !gh auth git-credential
[url "https://github.com/"]
    insteadOf = git@github.com:
EOF
    echo "✓ .gitconfig を生成しました"
else
    echo "ℹ️ .gitconfig は既に存在します"
fi
```

---

## 動作説明

1. **ホスト gitconfig の取り込み**: `[include] path = /tmp/gitconfig-host` により、ホストのユーザー名・メール・signingkey等の設定をそのまま継承
2. **HTTPS認証**: `gh auth git-credential` ヘルパーが `GH_TOKEN` 環境変数を使って認証
3. **SSH→HTTPSのURLリライト**: `url.insteadOf` により、既存リポジトリのSSHリモートURL (`git@github.com:xxx/yyy.git`) が自動的にHTTPS (`https://github.com/xxx/yyy.git`) に変換される

---

## 検証方法

1. devcontainerを再ビルドして起動
2. ワークスペース内のリポジトリで `git remote -v` を確認（SSHリモートでもHTTPS動作することを確認）
3. `git push` を実行して成功することを確認
4. `gh pr create` を実行してPR作成できることを確認

---

## リスクと注意事項

| リスク | 影響 | 対策 |
|--------|------|------|
| ホスト gitconfig の設定が `include` で正しく継承されない | GPG署名等が機能しない | `[include]` は git 2.13+ でサポート済み（問題なし）|
| GH_TOKEN の期限切れ | push失敗 | トークン管理はユーザー責任 (既存運用と同じ)|
| 既存の `~/.gitconfig` がある場合のスキップ | 設定が適用されない | `if [ ! -f ~/.gitconfig ]` でスキップするため、手動対処が必要 |

---

## 変更ファイル一覧

- `dot_config/devcontainer/devcontainer.json` - `.gitconfig` マウント先変更
- `dot_config/devcontainer/scripts/executable_post-create.sh` - gitconfig生成処理追加
