# アクセシビリティチェックリスト

Playwright CLI の snapshot（アクセシビリティツリー）を使用して確認する項目。

## チェック項目

### 1. 画像の代替テキスト

**確認方法**: snapshot 内の `img` ロールの要素に `name` プロパティ（alt 相当）があるか。

**✅ 合格**:
- すべての意味のある画像に alt 属性がある
- 装飾的な画像は `alt=""` または `role="presentation"` が設定されている
- alt テキストが画像の内容を適切に説明している

**❌ 不合格**:
- 意味のある画像に alt がない
- alt テキストが「画像」「image」等の無意味な値

**修正例** (templ):
```go
// Before
<img src="/static/logo.png">

// After
<img src="/static/logo.png" alt="サイトロゴ">
```

### 2. フォームラベル

**確認方法**: snapshot 内の input/select/textarea 要素に `name` プロパティ（label 相当）があるか。

**✅ 合格**:
- すべてのフォーム要素に `<label>` が紐づいている（`for` 属性、またはラベル要素でラップ）
- placeholder だけでなく label がある

**❌ 不合格**:
- input に label が紐づいていない
- placeholder のみで label がない

**修正例** (templ):
```go
// Before
<input type="email" placeholder="メールアドレス">

// After
<label for="email">メールアドレス</label>
<input type="email" id="email" placeholder="メールアドレス">
```

### 3. Heading 階層

**確認方法**: snapshot 内の heading ロール要素の `level` を確認。

**✅ 合格**:
- ページに h1 が1つある
- h1 → h2 → h3 のように順番にネストしている
- レベルのスキップがない（h1 の次に h3 はNG）

**❌ 不合格**:
- h1 がない、または複数ある
- heading レベルがスキップされている（h1 → h3）
- 見た目のために heading レベルを誤用している

### 4. キーボード操作

**確認方法**: `playwright-cli press Tab` を繰り返してフォーカス移動を確認。

**✅ 合格**:
- すべてのインタラクティブ要素（リンク、ボタン、フォーム）にフォーカスが到達する
- フォーカス順序が論理的（左上から右下へ）
- フォーカストラップがない（モーダル内は例外）
- Enterキーでボタン/リンクを実行できる

**❌ 不合格**:
- フォーカスが到達しない要素がある
- フォーカスが見えない（outline: none で消されている）
- Tab キーでフォーカスが巡回しない

**確認手順**:
```bash
playwright-cli press Tab     # 最初のフォーカス可能要素
playwright-cli snapshot      # フォーカス位置を確認
playwright-cli press Tab     # 次の要素
playwright-cli snapshot      # フォーカス位置を確認
# 繰り返す
```

### 5. ARIA 属性

**確認方法**: snapshot 内の要素の role と ARIA プロパティを確認。

**✅ 合格**:
- カスタムウィジェットに適切な role が設定されている
- `aria-label` や `aria-describedby` が必要な箇所に設定されている
- `aria-hidden="true"` が装飾的な要素にのみ使用されている
- ライブリージョン（`aria-live`）が動的コンテンツに設定されている

**❌ 不合格**:
- インタラクティブなカスタム要素に role がない
- `aria-hidden="true"` がインタラクティブ要素に設定されている
- 不適切な role の使用

### 6. コントラスト比

**確認方法**: スクリーンショットの視覚的確認 + Lighthouse 監査（DevTools MCP 利用時）。

**WCAG AA 基準**:
- 通常テキスト: 4.5:1 以上
- 大きなテキスト（18px以上、または14px太字以上）: 3:1 以上
- UIコンポーネント・グラフィカルオブジェクト: 3:1 以上

### 7. ランドマーク

**確認方法**: snapshot 内の `navigation`, `main`, `banner`, `contentinfo` ロールを確認。

**✅ 合格**:
- `<header>` (banner) が存在する
- `<nav>` (navigation) が存在する
- `<main>` (main) が存在する
- `<footer>` (contentinfo) が存在する

**❌ 不合格**:
- ランドマーク要素が一切ない（全てが `<div>` で構成）
- `<main>` がない

## Lighthouse 監査（Chrome DevTools MCP 利用時）

Chrome DevTools MCP が利用可能な場合、`lighthouse_audit` でアクセシビリティスコアを取得する。

```
スコア 90-100: ✅ 良好
スコア 70-89:  ⚠️ 改善推奨
スコア 0-69:   ❌ 要修正
```

## 報告フォーマット

```markdown
## アクセシビリティ結果

| チェック項目 | 結果 | 詳細 |
|------------|------|------|
| 画像alt属性 | ✅/❌ | N個中M個にalt設定済み |
| フォームラベル | ✅/❌ | N個中M個にlabel設定済み |
| Heading階層 | ✅/❌ | h1→h2→h3 の順序が正しい/不正 |
| キーボード操作 | ✅/❌ | N個中M個にフォーカス到達 |
| ARIA属性 | ✅/❌ | 不適切な使用N箇所 |
| コントラスト | ✅/⚠️/❌ | 問題のある箇所の説明 |
| ランドマーク | ✅/❌ | 存在するランドマーク一覧 |
| Lighthouse | XX/100 | (DevTools MCP利用時のみ) |
```
