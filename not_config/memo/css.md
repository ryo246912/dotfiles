# 1. CSS

## 1.1. flex

各要素の意味合い

- align: 要素の並び方向の交差方向での配置方法を設定 (通常は縦)
- justify: 要素の並び方向での配置方法を設定 (通常は横)

- content：ボックス全体に対して
- items：ボックス内にあるアイテム全てに対して
- self：設定されたアイテムに対して (flexbox 内では使用できない)

- 要素をどちらかに寄せたい
  →aligh-items:縦,justify-items:横
- 要素を等間隔で配置したい
  →aligh-contents:縦,justify-contents:横

### 1.1.1. css 詳細

- align-items: flex コンテナ内の要素全体に対して設定する(縦の位置、交差軸)
  すべての直接の子要素に集合として align-self の値を設定します。
  コンテナ内の縦方向(交差軸方向)に対する位置決め
  デフォルトだと、縦方向(主軸は横なので)、flex-direction:column の場合は横方向になる
  https://developer.mozilla.org/ja/docs/Web/CSS/align-items

- justify-items: flex コンテナ内の要素全体に対して設定する(横の位置、主軸)
  コンテナ内の横方向(主軸方向)に対する位置決め
  デフォルトだと、横方向、flex-direction:column の場合は縦方向になる

- align-content: flex コンテナ内の要素全体に対して設定する(横の位置、主軸)
  コンテナ内の横方向(主軸方向)に対する位置決め
  デフォルトだと、横方向、flex-direction:column の場合は縦方向になる

- justify-content: 横方向の要素の間隔周りを指定(横方向、主軸)
  - flex-start : 行頭寄せ(通常は左寄せ)
  - flex-end : 行末寄せ(通常右寄せ)
  - center: 中央寄せ
  - space-between : アイテム間をスペースで均等に割当

- align-self: flex コンテナ内の要素に対して個別に追加設定する
  - auto（初期値）: 親要素の align-items の値に従う
  - flex-start : 親要素の始端に配置（左 or 上）
  - flex-end : 親要素の終端に配置（右 or 下）
  - center : 親要素の中央に配置
  - baseline : flex アイテムのベースライン（テキストの下端）に配置
  - stretch : 親要素の横幅に合わせて flex アイテムを伸縮

## 1.2. その他

- はみ出した文字を...で設定
  - white-space: nowrap;
    テキストを1行に収めるためのスタイルです。
    テキストが改行されることを防ぎます。
  - text-overflow: ellipsis;
    テキストが要素の幅を超えた場合に、末尾に「...」を表示します。
    これにより、長いテキストが視覚的に切り詰められます。
  - overflow: hidden;
    要素の幅を超えた部分のテキストを非表示にします。
    これにより、要素外にテキストがはみ出ることを防ぎます。
  ```css
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
  ```
