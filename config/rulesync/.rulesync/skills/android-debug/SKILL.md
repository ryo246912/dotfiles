---
name: android-debug
description: USB で Mac に繋いだ Android 実機に、ローカルの dev server の Web 画面を開いて scrcpy で映し、adb と Chrome DevTools Protocol で操作・デバッグするスキル。`/android-debug localhost:3001 80 54321` のように URL と追加で転送するポートを渡し、実機での表示確認やログインなどの不具合調査をするときに使う。
targets:
  - claudecode
  - codexcli
---

# Android 実機での Web デバッグ

引数は `<URL> [port...]`（例: `localhost:3001/ja/list/land 80 54321`）。URL を USB で繋いだ Android 実機のブラウザで開き、
Mac に画面を映しながら操作・調査する。スキームの無い URL は `http://` を補う。URL が無ければ確認する。
URL の後ろのポートは、フロントエンドが呼ぶ API・バックエンド・Supabase などのポートで、URL のポートと一緒に転送する。
スクリーンショットなどの一時ファイルは scratchpad に置く。

## 手順

1. `command -v scrcpy adb` で導入を確かめる。無ければ `mise install github:Genymobile/scrcpy` で入れる。scrcpy の配布物に adb も入っている。
   設定に無い環境では、`brew install` ではなく `mise use --path ~/dotfiles/config/mise/config.<env>.toml github:Genymobile/scrcpy@<version>` で、
   その Mac 用の設定に追加する。`--path` を省くと、デバッグ中のプロジェクトの `mise.toml` に書き込まれる。
2. `adb devices -l` で端末を確かめる。状態が `device` の行が無い、または `unauthorized` なら、端末で USB デバッグを ON にして
   許可 dialog を承認するようユーザーに頼み、済んだと返るまで待つ。
3. `curl -s -o /dev/null -w '%{http_code}' <URL>` で dev server の応答を確かめる。200 か 3xx 以外なら、dev server の起動をユーザーに頼んで止まる。
4. scrcpy を Bash tool の background 実行で起動し、後片付けのために `pgrep -nx scrcpy` で PID を控える。前景で起動すると session が止まる。

   ```bash
   scrcpy --window-title 'Android' --stay-awake --max-size 1200 --window-x 100 --window-y 60
   ```

   位置を指定しないと外部ディスプレイ側に出て見つからないことがある。osascript でウィンドウを動かすには補助アクセスの権限が要るため、位置は起動オプションで決める。

5. 始める前の `adb reverse --list` を控えてから、URL のポートと引数のポートをそれぞれ `adb reverse tcp:<port> tcp:<port>` で転送し、`adb reverse --list` で確かめる。
   引数のポートは `lsof -nP -iTCP:<port> -sTCP:LISTEN` で Mac 側の待ち受けを確かめ、待ち受けていなければユーザーに伝える。
6. URL を開き、3 秒待ってスクリーンショットを撮って Read tool で見る。端末の既定ブラウザが Chrome でなければ `com.android.chrome` を外す。

   ```bash
   adb shell am start -a android.intent.action.VIEW -d '<URL>' com.android.chrome
   adb exec-out screencap -p > <scratchpad>/android.png
   ```

   読み込み中は白い画面になるので、空に見えたら数秒後に撮り直す。

## 操作

- タップ: `adb shell input tap <x> <y>`。Read tool で見た画像は縮小表示されるため、表示に添えられた倍率を掛けて実機の座標にする。
- 文字入力: `adb shell input text '<text>'`（空白は `%s`）。パスワードや認証コードはユーザーが入力するか、ユーザーから渡されたときだけ入れる。
- 送信などの副作用がある操作（ログイン、確認コードの再送になるボタン）は、押す前にその影響をユーザーに伝える。

## DevTools でのデバッグ

画面だけで原因が分からないとき（ログインできない、API が失敗するなど）は、端末のブラウザの DevTools に接続する。

1. `adb shell cat /proc/net/unix | grep -o '@[a-z_]*devtools_remote[_0-9a-z]*' | sed 's/^@//' | sort -u` でソケットを探す。
   先頭の `@` は抽象名前空間の印で、`localabstract:` に渡す名前には含めない。
   `chrome_devtools_remote` は前面のブラウザ（Chrome とは限らず、Edge のこともある）、`chrome_devtools_remote_<pid>` は pid のブラウザ。
   `adb shell ps -A | grep <pid>` でどのアプリか確かめる。
2. `adb forward tcp:9222 localabstract:<socket>` で転送する。
3. このスキルのディレクトリの `scripts/cdp-watch.mjs` を background 実行し、対象タブの通信・コンソール・例外を記録する。
   ユーザーに操作を再現してもらい、出力ファイルを読む。

   ```bash
   node <skill-dir>/scripts/cdp-watch.mjs 'http://localhost:<port>' 300
   ```

   接続した直後には、接続前に出ていたコンソールメッセージがまとめて再送され、同じ時刻で並ぶ。
   対処の前に出た古いエラーと取り違えないよう、`attached` の後に再現した操作のログで判断する。

`/json` のタブ一覧には、無関係な個人のタブの URL も含まれる。対象の URL の行だけを扱い、それ以外は回答に書かない。

## よくある原因

- `net::ERR_CONNECTION_REFUSED http://localhost/...`: フロントエンドが別ポート（`localhost` は 80）の API やバックエンドを呼んでいるのに、そのポートを転送していない。
  Mac 側で `lsof -nP -iTCP:<port> -sTCP:LISTEN` で待ち受けを確かめ、`adb reverse tcp:<port> tcp:<port>` を足す。
  次回からはそのポートを引数に足して呼び出すよう、ユーザーに伝える。
  外部の認証（Cognito など）が通っても、バックエンドへの login API が失敗するとアプリがサインアウトしてサインイン画面に戻る。
- USB を挿し直すと、`adb reverse` / `adb forward` の設定は消え、scrcpy も終了する。手順 2・4・5 をやり直す。
- 原因を探すためにプロジェクトの `.env` など秘密情報を含むファイルを読まない。待ち受けているポートと DevTools のログから判断する。

## 後片付け

作業を終えるときは、このスキルで起動した scrcpy と、追加した転送だけを外す。始める前からあった scrcpy や転送は残す。

```bash
kill <起動した scrcpy の PID>
adb forward --remove tcp:9222
adb reverse --remove tcp:<転送したポート>  # ポートごとに繰り返す
```
