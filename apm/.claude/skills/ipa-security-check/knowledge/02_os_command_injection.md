---
name: os_command_injection
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.2 OSコマンド・インジェクション"
ipa_page: "13-15"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/os-command.html
cwe: CWE-78
---

# OS コマンド・インジェクション (OS Command Injection)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.2 OS コマンド・インジェクション
- ページ: p.13〜15
- URL: https://www.ipa.go.jp/security/vuln/websecurity/os-command.html

## 概要

外部からの攻撃により、ウェブサーバの OS コマンドを不正に実行されてしまう脆弱性。ウェブアプリケーションが外部プログラム（シェルや別プロセス）を呼び出し可能な言語機能を使用する際、ユーザ入力が適切に検証・分離されないと、攻撃者が意図しない OS コマンドを連結・注入して実行できる。

CWE-78 に該当。Perl で開発されたウェブアプリケーションや、組み込み製品（無線 LAN ルータ等）の管理画面 CGI プログラムで発見例が多い。

## 脅威・被害

| 区分 | 内容 |
|---|---|
| ファイル | サーバ内ファイルの閲覧・改ざん・削除、重要情報の漏えい、設定ファイル改ざん |
| システム | OS の不正シャットダウン、ユーザアカウントの追加・変更 |
| マルウェア | 不正プログラムのダウンロード・実行、ウイルス/ワーム/ボットへの感染、バックドア設置 |
| 踏み台化 | サービス不能攻撃、他システムへの攻撃調査、迷惑メール送信 |

## 発生原因（言語別の危険な関数）

### Perl
- `open()` … 引数文字列にパイプ `|` を含めると、その後の文字列がシェルコマンドとして実行される
- `system()`
- `eval()`
- バッククォート（`` `...` ``）／qx//

### PHP
- `exec()`, `passthru()`, `shell_exec()`, `system()`, `popen()`, `proc_open()`
- バッククォート演算子

### Ruby
- `system`, `exec`, `` `...` ``, `IO.popen`, `Kernel.open`（パイプ付き）, `%x{}`

### Python
- `os.system`, `os.popen`, `subprocess.*(..., shell=True)`, `commands.getoutput`

### Java
- `Runtime.exec`, `ProcessBuilder`（シェル経由 `sh -c` を使うパターン）

### Node.js
- `child_process.exec`, `child_process.execSync`

### .NET
- `Process.Start`（`UseShellExecute=true` や `cmd.exe /c` を経由するパターン）

## 根本的解決策

### 2-(i) シェルを起動できる言語機能の利用を避ける

- 可能な限り、シェルを介さない代替関数で代替する
- 例: **Perl では `open()` ではなく `sysopen()` を使う**（IPA が明示）。`sysopen()` はシェルを起動しない
- 外部プログラム呼び出しが必要な場合、シェル展開を行わない「引数配列を直接渡す」インタフェースを用いる（例: `execve` 系、`subprocess.run([...], shell=False)`、`ProcessBuilder(List<String>)`）

## 保険的対策

### 2-(ii) 入力値検証（シェル起動機能を利用せざるを得ない場合）

「シェルを起動できる言語機能を利用する場合は、その引数を構成する全ての変数に対してチェックを行い、あらかじめ許可した処理のみを実行する」。

- **ホワイトリスト方式（推奨）**: 引数に許可する文字の組み合わせを列挙し、それ以外は拒否
  - 数値パラメータなら `^[0-9]+$` のみ許可、等
- **ブラックリスト方式（非推奨）**: `|`, `<`, `>`, `;`, `&`, `` ` ``, `$`, `(`, `)`, `\n` 等を弾く方式。漏れが生じやすく IPA は非推奨

## NG コードパターン (検出対象)

### Perl

```perl
# NG: open のパイプによりシェルコマンド実行
open(my $fh, "/usr/bin/grep $keyword file.txt|") or die;
```

### PHP

```php
// NG: 文字列連結でシェルへ渡す
system("convert " . $_GET['file'] . " out.png");
$out = shell_exec("ls " . $_GET['dir']);
exec("ping " . $_GET['host'], $output);
// NG: escapeshellarg / escapeshellcmd は保険、根本対策ではない
exec('ping ' . escapeshellarg($host), $output);
```

### Python

```python
# NG: shell=True かつ文字列連結
subprocess.call("ls " + user_input, shell=True)
os.system("convert " + filename + " out.png")
```

### Java

```java
// NG: sh -c に文字列を渡す
Runtime.getRuntime().exec("sh -c \"ls " + userInput + "\"");
```

### Ruby

```ruby
# NG: 文字列補間でシェルに渡す
system("ls #{params[:dir]}")
`ls #{params[:dir]}`
IO.popen("ls #{params[:dir]}")
```

### Node.js

```js
// NG: child_process.exec への文字列連結
child_process.exec("ls " + userInput);
```

## OK コードパターン (修正例)

### Perl

```perl
# OK: sysopen はシェルを起動しない
sysopen(my $fh, $filename, O_RDONLY) or die;

# OK: list-form は exec 直渡しでシェルを介さない
open(my $fh, '-|', '/usr/bin/grep', $keyword, 'file.txt');
system('/usr/bin/grep', $keyword, 'file.txt');
```

### Python

```python
# OK: 引数を list で渡し shell=False (デフォルト)
subprocess.run(["convert", filename, "out.png"], shell=False, check=True)
```

### Java

```java
// OK: ProcessBuilder + 引数配列
ProcessBuilder pb = new ProcessBuilder("ls", userInput);
pb.start();
```

### Ruby

```ruby
# OK: 引数を分離
system("ls", params[:dir])
IO.popen(["ls", params[:dir]])
```

### Node.js

```js
// OK
child_process.execFile("ls", [userInput]);
child_process.spawn("ls", [userInput]);
```

### PHP

```php
// OK: 可能なら言語標準 API で代替（シェル不使用）
$contents = file_get_contents($safe_path);
```

## 自動チェック観点

### 静的解析でカバー可能（◎）

- シェル起動関数（`system`, `exec`, `shell_exec`, `popen`, `passthru` 等）に文字列連結／テンプレートリテラル／文字列補間で外部入力を含めている
- Perl `open` の引数に `|` を含む文字列、または末尾 `|` がある
- `subprocess.*` / `child_process.exec` / `Runtime.exec` で 1 個の文字列にコマンド全体を渡している
- Python で `shell=True` が指定されている
- `escapeshellarg`/`escapeshellcmd` のみで対処（要レビュー）

### 静的解析でカバーしにくい

- 内部 API 経由のコマンド実行
- レスポンス本文に何も返さないコマンド実行

### 検出正規表現候補

```
# Perl: open に | 付き、または文字列補間
\bopen\s*\(\s*[^,]+,\s*["'][^"']*\$\w+[^"']*\|["']
\bopen\s*\(\s*[^,]+,\s*["'][^"']*\|\s*\$\w+

# Perl/PHP/Ruby: バッククォート + 変数
`[^`]*\$[A-Za-z_][^`]*`

# PHP: 危険関数 + 連結
\b(system|exec|passthru|shell_exec|popen|proc_open|pcntl_exec)\s*\([^)]*(\$_(GET|POST|REQUEST|COOKIE|SERVER)|\.\s*\$)

# Python: shell=True
subprocess\.(call|run|Popen|check_call|check_output)\s*\([^)]*shell\s*=\s*True
\bos\.(system|popen)\s*\(

# Java: Runtime.exec 文字列1個
Runtime\.getRuntime\(\)\.exec\(\s*["'][^"']*\+

# Ruby
\bsystem\s*\(\s*["'][^"']*#\{
\bIO\.popen\s*\(\s*["'][^"']*#\{

# Node.js
child_process\.(exec|execSync)\s*\(\s*[`"'][^`"']*(\$\{|\+)

# .NET
new\s+Process\s*\(\s*\)[^;]*UseShellExecute\s*=\s*true
Process\.Start\s*\(\s*["'][^"']*\+

# 保険的: escapeshellarg / escapeshellcmd 単独使用 (要レビュー)
\bescapeshell(arg|cmd)\s*\(
```

## 関連ルール ID

- IPA-SWS-2-OSI-001: シェル起動関数への文字列連結（2-(i) 違反）
- IPA-SWS-2-OSI-002: Perl `open` でパイプ付き引数（2-(i) 違反）
- IPA-SWS-2-OSI-003: Python `shell=True`（2-(i) 違反）
- IPA-SWS-2-OSI-004: Java `Runtime.exec` に文字列1個（2-(i) 違反）
- IPA-SWS-2-OSI-005: 入力ホワイトリスト検証なし（2-(ii) 違反）
- IPA-SWS-2-OSI-006: `escapeshellarg`/`escapeshellcmd` のみ依存

## 参考

- IPA「安全なウェブサイトの作り方 - 1.2 OSコマンド・インジェクション」: https://www.ipa.go.jp/security/vuln/websecurity/os-command.html
- CWE-78: https://cwe.mitre.org/data/definitions/78.html
- 届出事例: 複数のASUS製無線LANルータ / 「Usermin」 / 「Movable Type」
