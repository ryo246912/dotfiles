---
name: buffer_overflow
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.10 バッファオーバーフロー"
ipa_page: "45-47"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/bach-overflow.html
cwe: CWE-119
---

# バッファオーバーフロー (Buffer Overflow)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.10 バッファオーバーフロー
- ページ: p.45〜47 付近
- URL: https://www.ipa.go.jp/security/vuln/websecurity/bach-overflow.html

## 概要

プログラムが入力されたデータを適切に扱わない場合、プログラムが確保したメモリの領域を超えて領域外のメモリを上書きされ、意図しないコードが実行される脆弱性。

C、C++、アセンブラなどの直接メモリを操作できる言語で記述されている場合に発生する。現在のウェブアプリケーションのほとんどは PHP、Perl、Java などの直接メモリを操作できない言語を使っており、バッファオーバーフローの脆弱性の影響を受ける可能性は低い、と IPA は指摘している。

スタックバッファオーバーフロー、ヒープバッファオーバーフロー、整数オーバーフローからの派生（バッファサイズ計算の誤り）、フォーマット文字列攻撃等の関連クラスがある。

## 脅威・被害

- **プログラムの異常終了**（意図しないサービス停止 / DoS）
- **任意のコード実行**
  - ウイルス、ワーム、ボット等への感染
  - バックドアの設置
  - 他のシステムへの攻撃の踏み台化
  - 重要情報の漏えい

## 発生原因（C/C++ 危険関数）

IPA 当該ページには具体的な危険関数は列挙されていないが、一般に C/C++ では以下のような関数・パターンが代表的な原因となる（参考情報として補足）。

### 危険関数（境界チェックを行わない or 行いにくい）

- 文字列コピー: `strcpy`, `wcscpy`, `_mbscpy`
- 文字列連結: `strcat`, `wcscat`
- 書式付き出力: `sprintf`, `vsprintf`, `swprintf`（バッファサイズ指定なし版）
- 入力取得: `gets`（C11 で削除）, `scanf("%s", ...)`, `fscanf("%s", ...)`
- メモリコピー: `memcpy`, `memmove` でサイズに外部入力を使い検証していない
- フォーマット文字列攻撃: `printf(user_input)` のように書式文字列に外部入力を渡す

### 危険パターン例

```c
// NG: 入力サイズ未検証で固定バッファへコピー
char buf[64];
strcpy(buf, argv[1]);

// NG: gets はバッファ長を取れない
char line[128];
gets(line);

// NG: sprintf も書式と引数次第で容易にオーバーフロー
char out[32];
sprintf(out, "%s-%s", a, b);

// NG: フォーマット文字列攻撃
printf(user_input);     // %n などで任意書き込み

// NG: 整数オーバーフローでサイズ計算誤り
size_t n = count * sizeof(item_t);
item_t *p = malloc(n);
memcpy(p, src, count * sizeof(item_t));
```

## 根本的解決策

### 10-(i)-a 直接メモリにアクセスできない言語で記述

ウェブアプリケーションを直接メモリ操作できない言語（PHP、Perl、Java、Ruby、Python、Go、C# 等）で記述することで、バッファオーバーフローの脆弱性が作りこまれることを防げる。

### 10-(i)-b 直接メモリ操作可能な言語で記述された部分を最小限にする

C/C++ 等で記述する部分を最小限にし、その部分にバッファオーバーフローの脆弱性がないことを集中的に確認する。

### 10-(ii) 脆弱性が修正された最新バージョンのライブラリを使用する

古いライブラリには既知のバッファオーバーフロー脆弱性が存在する場合があるため、修正版を使用する。

## 保険的対策

IPA 当該ページには明示的な保険的対策は記載されていない（参考として、業界一般的には以下のような緩和策が用いられる）。

- コンパイラのスタック保護機能（`-fstack-protector-strong`, `/GS`）
- アドレス空間配置のランダム化（ASLR）
- 実行不可スタック（NX bit / DEP）
- Position Independent Executable (`-fPIE` / `-pie`)
- FORTIFY_SOURCE (`-D_FORTIFY_SOURCE=2`)
- AddressSanitizer / Valgrind 等によるテスト
- OS・ライブラリの最新化

## 安全な代替関数（参考）

| 危険関数 | 推奨代替 | 備考 |
|---|---|---|
| `strcpy` | `strncpy`（NUL 終端注意）/ `strlcpy` / `strcpy_s` | `strncpy` はバッファが埋まると NUL 終端されない |
| `strcat` | `strncat` / `strlcat` / `strcat_s` | `strncat` の第 3 引数は **残り** 長さ |
| `sprintf` | `snprintf` / `sprintf_s` | サイズを必ず指定 |
| `vsprintf` | `vsnprintf` | 同上 |
| `gets` | `fgets`（C11 で `gets` は削除済） | 必ずサイズ指定 |
| `scanf("%s", ...)` | `scanf("%<N>s", ...)` / `fgets` | 幅指定必須 |
| `memcpy` | サイズ検証＋ `memcpy_s`（C11 Annex K） | 整数オーバーフローに注意 |

### C++ では std::string / std::vector を使う

```cpp
std::string s = a + "-" + b;
std::vector<int> v(count);
```

## NG コードパターン (検出対象)

- C/C++ ソース中で危険関数の使用: `strcpy(`, `strcat(`, `sprintf(`, `vsprintf(`, `gets(`, `scanf("%s"`, `fscanf("%s"`, `getwd(`, `realpath(`（古い API の固定バッファ版）
- `memcpy(` / `memmove(` のサイズ引数が外部入力で、サイズ検証コードがない
- `printf(user_input)` 等の **フォーマット文字列に外部入力**
- `alloca(n)` で `n` に外部入力
- 固定長スタックバッファ（`char buf[N];`）への外部入力コピー
- 整数オーバーフローの可能性のあるサイズ計算（`a * b` がそのまま `malloc` 引数）
- ライブラリ／コンパイラのバージョンが古い、ビルドオプションに `-fstack-protector`, `-D_FORTIFY_SOURCE` が含まれない

## OK コードパターン (修正例)

### C（安全に書き直した例）

```c
// 修正版: strncpy + NUL 終端 / snprintf / fgets
char buf[64];
strncpy(buf, argv[1], sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';

char line[128];
if (fgets(line, sizeof(line), stdin) == NULL) { /* error */ }

char out[32];
int n = snprintf(out, sizeof(out), "%s-%s", a, b);
if (n < 0 || (size_t)n >= sizeof(out)) { /* truncated */ }

// 整数オーバーフロー対策
if (count > SIZE_MAX / sizeof(item_t)) { /* error */ }
size_t bytes = count * sizeof(item_t);
item_t *p = malloc(bytes);
```

### C++

```cpp
#include <string>
#include <vector>
std::string out = std::string(a) + "-" + b;
std::vector<uint8_t> buf(size);
```

## 自動チェック観点

### 静的解析でカバー可能（◎ C/C++ のみ）

- 危険関数の使用検出
- `printf` 系第1引数が変数（フォーマット文字列攻撃）
- 固定長スタックバッファ宣言
- ビルドオプションに保護機能が含まれない

### 検出正規表現候補

C/C++ ソース対象。識別子の前後を `\b` で境界付けして誤検出を抑制する。

```
# 危険関数の使用
\bstrcpy\s*\(
\bstrcat\s*\(
\bsprintf\s*\(
\bvsprintf\s*\(
\bgets\s*\(
\bscanf\s*\(\s*"[^"]*%s
\bfscanf\s*\(\s*[^,]+,\s*"[^"]*%s
\bgetwd\s*\(
\b_mbscpy\s*\(
\bwcscpy\s*\(
\bwcscat\s*\(
\balloca\s*\(

# memcpy / memmove のサイズに外部入力
\bmem(cpy|move)\s*\([^,]+,[^,]+,[^)]*\b(argv|argc|input|size|len|n)\b

# フォーマット文字列攻撃の兆候
\b(printf|fprintf|sprintf|snprintf|syslog)\s*\(\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\)
\b(printf|fprintf|sprintf|snprintf|syslog)\s*\(\s*[a-zA-Z_][a-zA-Z0-9_]*\s*,

# 固定長スタックバッファ宣言
\bchar\s+\w+\s*\[\s*\d+\s*\]\s*;

# ビルドオプション（Makefile / CMakeLists）— 欠如検査
-fstack-protector
-D_FORTIFY_SOURCE
-Wformat-security
```

#### 推奨パターン検出（存在を確認）

```
\bstrn(cpy|cat)\s*\(
\bstrl(cpy|cat)\s*\(
\b(strncpy|strcat|sprintf|memcpy)_s\s*\(
\bsnprintf\s*\(
\bvsnprintf\s*\(
\bfgets\s*\(
std::(string|vector|array|span)
```

### Skill のチェックフロー

1. プロジェクトの言語を判定（`*.c`, `*.cc`, `*.cpp`, `*.h`, `*.hpp` が存在するか）
2. 存在しなければ「対象外（メモリ安全な言語のみ）」として軽く通過
3. 存在する場合、危険関数のヒット箇所を列挙
4. 各ヒットについて、安全な代替への置換、または入力サイズ検証コードの有無を文脈で確認
5. Makefile / CMakeLists / コンパイラフラグに保護オプションがあるか確認
6. 依存ライブラリのバージョンが最新かを確認（パッケージマネージャの lock ファイル等）

### ネイティブ拡張・FFI

- Node.js の `node-gyp`、Python の `cffi`/`ctypes`、Ruby の `ffi` 等
- 主に「依存ライブラリの CVE 検出」と統合する

## 関連ルール ID

- IPA-SWS-10-BOF-001: メモリ非安全言語の使用検出（10-(i)-a 適用範囲）
- IPA-SWS-10-BOF-002: 危険関数 `strcpy`/`strcat`/`sprintf`/`gets`/`scanf("%s")` の使用
- IPA-SWS-10-BOF-003: フォーマット文字列に外部入力
- IPA-SWS-10-BOF-004: ネイティブ部分の最小化未実施（10-(i)-b 違反）
- IPA-SWS-10-BOF-005: 古い CVE 持ちライブラリの利用（10-(ii) 違反）
- IPA-SWS-10-BOF-006: コンパイラ保護オプション欠如（`-fstack-protector` / `-D_FORTIFY_SOURCE` 等）

## 参考

- IPA「安全なウェブサイトの作り方 - 1.10 バッファオーバーフロー」: https://www.ipa.go.jp/security/vuln/websecurity/bach-overflow.html
- CWE-119（バッファエラー）: https://cwe.mitre.org/data/definitions/119.html
- JVNDB CWE-119: https://jvndb.jvn.jp/ja/cwe/CWE-119.html
- 脆弱性事例: 複数のサイボウズ製品 (JVNDB-2014-000130) / Oracle Outside In (JVNDB-2013-000070) / 茶筌 (JVNDB-2011-000099)
