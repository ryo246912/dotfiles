---
name: ipa-sources
purpose: IPA 5 資料の出典マスター
---

# IPA 公式資料 出典マスター

本 Skill で参照する IPA（独立行政法人 情報処理推進機構）公式資料の正式名称・版・発行日・URL の一次情報源。
各 knowledge/*.md の frontmatter (`ipa_document`, `ipa_section`, `ipa_page`, `ipa_url`) は本ファイルの値に従う。

## 1. 安全なウェブサイトの作り方 改訂第7版

| 項目 | 値 |
| --- | --- |
| 正式名称 | 安全なウェブサイトの作り方 |
| 版 | 改訂第7版 第4刷 |
| 発行日 | 2021年3月31日 |
| ページ数 | 115 ページ |
| 発行者 | 独立行政法人 情報処理推進機構（IPA） |
| PDF URL | https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf |
| 紹介ページ URL | https://www.ipa.go.jp/security/vuln/websecurity/about.html |
| 目次系統 | 第1章 ウェブアプリケーションのセキュリティ実装 / 第2章 ウェブサイトの安全性向上のための取り組み / 第3章 失敗例 / 巻末 チェックリスト・CWE 対応表 |

### 版の系譜

| 版 | 初版発行日 |
| --- | --- |
| 第1版 第1刷 | 2006年1月31日 |
| 改訂第2版 | 2006年11月1日 |
| 改訂第3版 | 2008年3月6日 |
| 改訂第4版 | 2010年1月20日 |
| 改訂第5版 | 2011年4月6日 |
| 改訂第6版 | 2012年12月26日 |
| 改訂第7版 第1刷 | 2015年3月12日 |
| 改訂第7版 第2刷 | 2015年3月26日 |
| 改訂第7版 第3刷 | 2016年1月27日 |
| 改訂第7版 第4刷 | 2021年3月31日 |

### 第1章 11脆弱性と当該ページ URL

| 章節 | 脆弱性 | ページ概略 | 当該ページ URL |
| --- | --- | --- | --- |
| 1.1 | SQL インジェクション | p.6-12 | https://www.ipa.go.jp/security/vuln/websecurity/sql.html |
| 1.2 | OS コマンド・インジェクション | p.13-15 | https://www.ipa.go.jp/security/vuln/websecurity/os-command.html |
| 1.3 | パス名パラメータの未チェック／ディレクトリ・トラバーサル | p.16-18 | https://www.ipa.go.jp/security/vuln/websecurity/parameter.html |
| 1.4 | セッション管理の不備 | p.19-25 | https://www.ipa.go.jp/security/vuln/websecurity/session-management.html |
| 1.5 | クロスサイト・スクリプティング（XSS） | p.26-32 | https://www.ipa.go.jp/security/vuln/websecurity/cross-site-scripting.html |
| 1.6 | CSRF | p.33-38 | https://www.ipa.go.jp/security/vuln/websecurity/csrf.html |
| 1.7 | HTTP ヘッダ・インジェクション | p.39-41 | https://www.ipa.go.jp/security/vuln/websecurity/http-header.html |
| 1.8 | メールヘッダ・インジェクション | p.42-44 | https://www.ipa.go.jp/security/vuln/websecurity/mail-header.html |
| 1.9 | クリックジャッキング | p.45-47 | https://www.ipa.go.jp/security/vuln/websecurity/clickjacking.html |
| 1.10 | バッファオーバーフロー | p.45-47 | https://www.ipa.go.jp/security/vuln/websecurity/bach-overflow.html |
| 1.11 | アクセス制御や認可制御の欠落 | p.45-47 | https://www.ipa.go.jp/security/vuln/websecurity/access-control.html |

## 2. 別冊：安全なSQLの呼び出し方

| 項目 | 値 |
| --- | --- |
| 正式名称 | 安全なSQLの呼び出し方（「安全なウェブサイトの作り方」別冊） |
| 版 | 第1版 |
| 発行日 | 2010年3月18日 |
| ページ数 | 40 ページ |
| 発行者 | 独立行政法人 情報処理推進機構（IPA） |
| 執筆者 | 徳丸 浩、永安 佑希允、相馬 基邦、勝海 直人、高木 浩光（産業技術総合研究所） |
| PDF URL | https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf |
| 関連 URL | https://www.ipa.go.jp/security/vuln/websecurity.html |
| 構成 | 第1〜2章 概論・SQL構造とリテラル / 第3章 バインド機構 / 第4章 エスケープ / 第5章 言語別実装 / 付録A 文字エンコーディング |

## 3. 別冊：ウェブ健康診断仕様

| 項目 | 値 |
| --- | --- |
| 正式名称 | ウェブ健康診断仕様（「安全なウェブサイトの作り方」別冊） |
| 版 | 第1版 第1刷 |
| 発行日 | 2012年12月26日 |
| ページ数 | 30 ページ |
| 発行者 | 独立行政法人 情報処理推進機構（IPA） |
| 編集責任 | 小林 偉昭 |
| 原典 | 財団法人地方自治情報センター（LASDEC）「ウェブ健康診断事業」（平成20年度版/平成22年度版） |
| PDF URL | https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017319.pdf |
| 関連 URL | https://www.ipa.go.jp/security/vuln/websecurity.html |

13 診断項目（A）〜（M）の一覧は `web_health_check.md` 参照。

## 4. 安全なウェブサイトの運用管理に向けての20ヶ条

| 項目 | 値 |
| --- | --- |
| 正式名称 | 安全なウェブサイトの運用管理に向けての20ヶ条 |
| 発行者 | 独立行政法人 情報処理推進機構（IPA） |
| URL | https://www.ipa.go.jp/security/vuln/websecurity/sitecheck.html |

第1〜20条の詳細は `operation_checklist.md` 参照。

## 5. セキュリティ実装チェックリスト

| 項目 | 値 |
| --- | --- |
| 正式名称 | セキュリティ実装チェックリスト |
| 出典 | 「安全なウェブサイトの作り方」改訂第7版 巻末（p.105〜108） |
| Excel URL | https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000044403.xlsx |
| PDF URL | https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf （巻末 p.105〜） |

全11カテゴリ × 項目ID（例: 1-(i)-a）のチェック項目は `operation_checklist.md` 参照。

## 6. 共通脆弱性タイプ一覧 CWE 概説

| 項目 | 値 |
| --- | --- |
| 名称 | 共通脆弱性タイプ一覧 CWE 概説 |
| URL | https://www.ipa.go.jp/security/vuln/CWE.html |

## 7. 脆弱性関連情報の届出

| 項目 | 値 |
| --- | --- |
| 名称 | 脆弱性関連情報の届出 |
| URL | https://www.ipa.go.jp/security/vuln/report/index.html |

## CWE 対応表（「安全なウェブサイトの作り方」改訂第7版 p.109〜）

| カテゴリ | CWE-ID |
| --- | --- |
| SQL インジェクション | CWE-89 |
| OS コマンド・インジェクション | CWE-78 |
| パス名パラメータの未チェック／ディレクトリ・トラバーサル | CWE-22 |
| セッション管理の不備 | CWE-330 / CWE-384 / CWE-522 / CWE-614 |
| クロスサイト・スクリプティング | CWE-79 |
| CSRF | CWE-352 |
| HTTP ヘッダ・インジェクション | CWE-113 |
| メールヘッダ・インジェクション | CWE-93 |
| クリックジャッキング | 直接対応 CWE なし（補足: CWE-1021） |
| バッファオーバーフロー | CWE-119 |
| アクセス制御や認可制御の欠落 | CWE-264 / CWE-287（補足: CWE-284 / CWE-285 / CWE-639 / CWE-862 / CWE-863） |

## ライセンス・著作権

- 全資料の著作・制作: 独立行政法人 情報処理推進機構（IPA）
- 本 Skill 同梱の knowledge ファイルは IPA 公式資料を二次的に整理した参照用ノートであり、原典のライセンス・著作権は IPA に帰属する。

## 用語の前提（IPA 資料に準拠）

- **根本的解決**: 脆弱性を作り込まない実装を実現する手法。脆弱性そのものを無効化する。
- **保険的対策**: 攻撃による影響を軽減する対策。原因を除去はしないが、(1) 攻撃可能性の低減 / (2) 脆弱性が突かれる可能性の低減 / (3) 被害範囲の最小化 / (4) 早期検知 のいずれかで効果を発揮する。

Skill の finding 出力では、提案を必ず「根本的解決」と「保険的対策」に区別して提示すること。
