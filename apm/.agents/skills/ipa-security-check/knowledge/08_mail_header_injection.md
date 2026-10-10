---
name: mail_header_injection
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.8 メールヘッダ・インジェクション"
ipa_page: "42-44"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/mail-header.html
cwe: CWE-93
---

# メールヘッダ・インジェクション (Mail Header Injection / CRLF Injection)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.8 メールヘッダ・インジェクション
- ページ: p.42〜44
- URL: https://www.ipa.go.jp/security/vuln/websecurity/mail-header.html

## 概要

ウェブアプリケーションから利用者の入力内容（商品申し込み、アンケート、お問い合わせ等）を特定のメールアドレスに送信する機能において、ユーザ入力を適切に検証せず、メールヘッダの生成に直接使用すると発生する脆弱性。

メールメッセージは HTTP と同様に「改行（CRLF）でヘッダ行が区切られ、空行の後ろが本文」というテキスト形式のため、攻撃者が改行コード（`%0d%0a`, `\r\n`）を含む入力を送り込むことで、任意のメールヘッダ追加・本文改ざんが可能となる。

CWE-93 (CRLF Injection) に該当。届出全体に占める割合は 1% 未満だが、受付開始当初から断続的に届出を受けている。

## 脅威・被害

| 区分 | 内容 |
|---|---|
| 第三者中継 | 任意宛先へのメール送信（迷惑メール送信踏み台） |
| Bcc 追加 | 攻撃者が `Bcc:` ヘッダを注入し、秘密裏に第三者へメール複製を送信 |
| 件名・本文改ざん | `Subject:` 改変や、改行 + 空行注入による本文部分の差し替え（詐欺メール送信） |
| 宛先改ざん | `To:` / `Cc:` ヘッダ追加による任意宛先への送信 |

## 危険な文字列パターン（入力に混入し得るもの）

- `%0d%0a` (URL エンコード形式の CRLF)
- `\r\n` （生バイナリ形式）
- `\n` 単独
- `Bcc:`, `Cc:`, `Content-Type:` 等のヘッダ名を含む文字列

## 脆弱になりやすい入力フィールドと出力先

| 入力 | 出力先ヘッダ |
|---|---|
| 氏名 | `From:`, `Reply-To:` |
| メールアドレス | `From:`, `To:`, `Reply-To:` |
| 件名 | `Subject:` |
| その他 | `Cc:`, `Bcc:`, `MIME-Version:`, `Content-Type:` |

## 根本的解決策

### 8-(i)-a メールヘッダを固定値にする（最推奨）

**原則**: 「外部からの入力はすべてメール本文に出力する」。

`To:`, `From:`, `Subject:` 等のヘッダ値はソースコード上の固定値とし、ユーザ入力はメール本文の中に埋め込む。これがもっとも安全。

### 8-(i)-b メール送信用 API を使用する場合

実行環境・言語に用意されているメール送信用 API を使用する（PHP `mb_send_mail`/`mail`、Java `JavaMail`、Ruby `Mail`/`ActionMailer` 等）。

ただし注意:

- API によっては改行コード処理が不適切なものや、複数ヘッダ挿入を許す仕様のものがある
- **脆弱性が修正されたバージョン**を使うことが必須
- API に渡す前に以下のいずれかを実施:
  - 改行コード後に空白／水平タブを挿入し、継続行として無害化
  - 改行コード以降の文字を削除
  - 改行が含まれていたら処理中止

### 8-(ii) HTML 側で宛先を指定しない

hidden パラメータ等で宛先メールアドレスをクライアントに保持・送信する設計は禁止する。宛先はサーバ側コードに固定値として持つか、サーバ側のテーブル/ID マッピングで決定する。

## 保険的対策

### 8-(iii) 改行コードの削除

外部からの入力すべてについて、ヘッダに渡す前に改行コード（必要に応じ制御コード全般）を削除する。

**注意**: メール本文に出力するデータ等、改行コードを含みうる文字列に対しては、一律削除を行うとアプリの正常動作が崩れる可能性があるため、適用箇所はヘッダ用に限定する。

## NG コードパターン (検出対象)

### PHP
```php
// NG: ヘッダ引数に外部入力を直接渡す
$to      = $_POST['to'];               // hidden で渡された宛先
$subject = $_POST['subject'];
$headers = "From: " . $_POST['from'] . "\r\n";
mail($to, $subject, $body, $headers);
```

### Perl
```perl
# NG: sendmail パイプ + 変数埋め込みヘッダ
open(my $mh, '|-', '/usr/sbin/sendmail', '-t', '-i') or die;
print $mh "From: $from\n";    # $from に改行が混入し得る
print $mh "Subject: $subject\n\n";
```

### Python
```python
# NG: smtplib.sendmail / 自前ヘッダ
msg['To'] = request.GET['to']
msg['Subject'] = request.GET['subject']
```

### Ruby (ActionMailer)
```ruby
# NG: params を直接ヘッダへ
mail(to: params[:to], subject: params[:subject])
```

### Node.js (nodemailer)
```js
// NG
transporter.sendMail({
  to: req.body.to,
  from: req.body.from,
  subject: req.body.subject,
  text: req.body.body
});
```

### HTML
```html
<!-- NG: hidden で宛先を指定 -->
<input type="hidden" name="to" value="info@example.com">
```

## OK コードパターン (修正例)

### PHP
```php
$to = 'info@example.com';                 // 固定
$from = preg_replace('/[\r\n]/', '', $_POST['email']);
if ($from === '' || strlen($from) !== strlen($_POST['email'])) {
    http_response_code(400); exit;
}
$subject = preg_replace('/[\r\n]/', '', $_POST['subject']);
mb_send_mail($to, $subject, $body, "From: $from");
```

### Java (JavaMail)
```java
MimeMessage msg = new MimeMessage(session);
msg.setFrom(new InternetAddress(safeFrom));  // InternetAddress が形式検証
msg.addRecipient(Message.RecipientType.TO, new InternetAddress("info@example.com"));
msg.setSubject(safeSubject, "UTF-8");        // 改行を含むと例外
msg.setText(body, "UTF-8");
Transport.send(msg);
```

### Perl
```perl
for my $v ($from, $subject) {
    $v =~ s/[\r\n].*//s;
}
open(my $mh, '|-', '/usr/sbin/sendmail', '-t', '-i') or die;
print $mh "To: info\@example.com\n";
print $mh "From: $from\n";
print $mh "Subject: $subject\n\n";
print $mh $body;
close($mh);
```

### Ruby (Mail / ActionMailer)
```ruby
# Mail gem / ActionMailer は CRLF 含む値で ArgumentError を投げる
Mail.deliver do
  to      'info@example.com'             # 固定
  from    params[:email]                  # ライブラリが検証
  subject params[:subject]
  body    params[:body]
end
```

### Python (email)
```python
from email.message import EmailMessage
msg = EmailMessage()
msg['To'] = 'info@example.com'    # 固定
msg['From'] = safe_from           # 事前に改行除去
msg['Subject'] = safe_subject     # 事前に改行除去
msg.set_content(body)
```

## 自動チェック観点

### 静的解析でカバー可能（◎）

- `mail()`, `mb_send_mail()` の `$to`, `$subject`, `$additional_headers` に `$_GET`/`$_POST`/`$_REQUEST`/`$_COOKIE` から取得した値が直接（または連結で）渡っている
- `sendmail` をパイプ起動して、ヘッダ行に外部入力を直接埋め込んでいる
- メール送信処理の前に CRLF (`\r` / `\n` / `%0d` / `%0a`) 検出が行われていない
- hidden パラメータで `to` / `recipient` / `mail_to` を渡している HTML がある
- `Bcc:` / `Cc:` / `Subject:` / `From:` を含むテンプレート文字列に外部入力を `.` や `${...}` で連結

### 検出正規表現候補

```
# PHP: mail / mb_send_mail に外部入力
\b(mail|mb_send_mail)\s*\([^)]*\$_(GET|POST|REQUEST|COOKIE)
\b(mail|mb_send_mail)\s*\([^)]*\.\s*\$

# PHP: ヘッダ生成文字列に外部入力連結
["'](From|To|Cc|Bcc|Subject|Reply-To)\s*:[^"']*["']\s*\.\s*\$_(GET|POST|REQUEST|COOKIE)

# Perl: sendmail パイプ + 変数埋め込みヘッダ
print\s+\$\w+\s+["'](From|To|Subject|Cc|Bcc):[^"']*\$\w+
open\s*\([^,]+,\s*["']\|.*sendmail

# Python: smtplib.sendmail / 自前ヘッダ
smtplib\.[A-Z]\w*\([^)]*\)\.sendmail\s*\([^)]*request\.
msg\[['"](To|From|Subject|Cc|Bcc)['"]\]\s*=\s*request\.

# Ruby: Mail gem / ActionMailer に params を直接ヘッダへ
\b(to|from|cc|bcc|subject)\s+params\[
mail\s*\(\s*to:\s*params\[

# Node.js: nodemailer
transporter\.sendMail\s*\(\s*\{[^}]*(to|from|subject|cc|bcc)\s*:\s*req\.(query|body|params)

# 入力中の CRLF / ヘッダ名混入検出
%0d%0a|%0a%0d|\\r\\n
\b(Bcc|Cc|Subject|From|To|Content-Type)\s*:

# HTML: hidden に宛先メールアドレス
<input[^>]+type=["']?hidden["']?[^>]+name=["']?(to|recipient|mail_to|mailto)["']?[^>]+value=["'][^"']+@

# OK signal: 改行除去 / バリデーション
preg_replace\s*\(\s*['"]/\[\\r\\n\]
\.gsub\s*\(\s*\/\[\\r\\n\]
re\.sub\s*\(\s*r['"]\[\\r\\n\]
```

## 関連ルール ID

- IPA-SWS-8-MHI-001: メールヘッダに外部入力直接埋め込み（8-(i)-a 違反）
- IPA-SWS-8-MHI-002: メール送信 API への入力直渡し（8-(i)-b 違反 + 改行検証なし）
- IPA-SWS-8-MHI-003: HTML 側で hidden に宛先指定（8-(ii) 違反）
- IPA-SWS-8-MHI-004: 改行コード除去未実施（8-(iii) 違反）

## 参考

- IPA「安全なウェブサイトの作り方 - 1.8 メールヘッダ・インジェクション」: https://www.ipa.go.jp/security/vuln/websecurity/mail-header.html
- CWE-93 (CRLF Injection): https://cwe.mitre.org/data/definitions/93.html
- 届出事例: JVNDB-2013-000116 サイボウズ ガルーン / JVNDB-2009-000023 CGI RESCUE「フォームメール」 / JVNDB-2007-000229 MailDwarf
