---
name: chrome-capture
description: Chrome や Chromium のタブを AV1 MP4 に録画する。指定 URL を開いて一定時間のタブ録画を依頼されたときに使う。
targets:
  - claudecode
  - codexcli
---

# Chrome タブの録画

mise で管理している `chrome-capture` を使う。Node.js 24.11 以降と Chrome または Chromium 153 以降が必要。

```bash
mise exec -- chrome-capture 'https://example.com/' './capture-<timestamp>.mp4' 4s --no-audio
```

- URL、出力先、録画時間は依頼に合わせる。例の `<timestamp>` は実際の日時に置き換える。時間の指定がなければ 4 秒、解像度とフレームレートは CLI の既定値（1280×720、60 fps）を使う。
- 音声が必要な場合は `--no-audio` を `--audio` に変える。解像度やフレームレートの変更には `--width`、`--height`、`--fps` を使う。
- ブラウザが自動検出されない場合は `--chrome=/path/to/chrome` で実行ファイルを指定する。CLI は録画用のブラウザセッションを新しく起動する。
- 出力先の親ディレクトリを用意し、上書きの指定がなければ未使用のファイル名を使う。
- 録画後は MP4 が生成されていることとファイルサイズが 0 でないことを確認する。`ffprobe` が使える場合は映像の形式と録画時間も確認し、保存先を伝える。
