# ov

多機能なターミナル pager。バージョンは `config/mise/config.toml`、設定は
`config/ov/config.yaml` で管理する。

## 導入

dotfiles の checkout ルートで実行する。

```sh
mise bootstrap dotfiles diff
mise bootstrap dotfiles apply
mise install aqua:noborus/ov
exec zsh -l
ov --version
```

設定ファイルは `~/.config/ov/config.yaml` に配置され、zsh 補完は初回起動時に
`~/.cache/mise/completions/_ov` へ生成される。

## 使い方

```sh
ov file.log
command | ov
ov -f file.log
ov -H1 -c -d ',' data.csv
```

- `j` / `k`、矢印キー: 上下移動
- `/`: 検索、`n` / `N`: 次 / 前の検索結果
- `w`: 折り返し切り替え
- `q`: 終了

初期設定は行番号表示・折り返しなし・smart case 検索。
既定の pager として使う場合はシェルで `export PAGER=ov` を設定する。
