# /last30days-skill 導入・使い方ガイド

## 1. 概要

`/last30days`は、指定したトピックについて過去30日間の情報を複数のソース（Reddit, X, YouTube, Hacker News, Polymarketなど）から収集し、コミュニティで実際に話題になっている内容や評価を要約して提供するスキルです。

## 2. 主な機能

- **マルチソース検索**: Reddit, X, YouTube, Hacker News, Polymarket, Bluesky, TikTok, Instagramなど最大10のソースを並列検索。
- **品質スコアリング**: エンゲージメント（いいね、リツイートなど）、新しさ、ソースの信頼性などに基づいて結果をランク付け。
- **クロスプラットフォーム検出**: 複数のプラットフォームで話題になっている重要なニュースを特定。
- **Xハンドル解決**: トピックに関連する公式アカウントを特定し、キーワード検索では漏れる可能性のある投稿も収集。
- **自動保存**: 調査結果は `~/Documents/Last30Days/` にマークダウンファイルとして自動保存されます。

## 3. インストール方法

### Claude Code (推奨)

```bash
/plugin marketplace add mvanhorn/last30days-skill
/plugin install last30days@last30days-skill
```

### Gemini CLI

```bash
gemini extensions install https://github.com/mvanhorn/last30days-skill.git
```

### 手動インストール (Claude Code / Codex)

```bash
git clone https://github.com/mvanhorn/last30days-skill.git ~/.claude/skills/last30days
```

## 4. セットアップとソースの有効化

### 4.1. 設定なしで利用可能なソース

Reddit (パブリックJSON), Hacker News, Polymarket は、インストール後すぐに利用可能です。

### 4.2. セットアップウィザード

以下のコマンドを実行して、ブラウザからX/Twitterのクッキーを抽出したり、必要なツール（yt-dlpなど）のチェックを行います。

```bash
/last30days setup
```

### 4.3. APIキーの追加 (オプション)

より高品質な結果を得るために、以下のAPIキーを `~/.config/last30days/.env` に追加することが推奨されます。

- **Exa API Key**: セマンティックウェブ検索用（無料枠あり）。
- **ScrapeCreators API Key**: Redditのコメント、TikTok、Instagramの検索用（推奨）。

## 5. 使い方

### 基本コマンド

```bash
/last30days <トピック>
```

### オプション

- `--days=N`: 過去N日間の情報を検索（例: `--days=7` で直近1週間）。
- `--quick`: 精度よりも速度を優先して検索。
- `--agent`: 対話型ではなく、レポート形式で出力。

### 比較モード

2つのトピックを比較します。

```bash
/last30 <トピックA> vs <トピックB>
```

## 6. セキュリティとプライバシー

- APIキーは各エンドポイントにのみ送信されます。
- Xのクッキーはメモリ内にのみ保持され、ディスクには保存されません。
- 調査トピックは各プラットフォームのAPIに送信されます。

---

出典: [mvanhorn/last30days-skill](https://github.com/mvanhorn/last30days-skill)
