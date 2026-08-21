# Raycast と Tinycast

## インストール

macOS のパッケージ bootstrap で Raycast と Tinycast を導入する。

```sh
mise run bootstrap:mac-packages
```

Tinycast は公式 tap の cask を利用する。サードパーティ tap の Homebrew API メタデータが
公開されていないため、`[bootstrap.packages]` の `brew-cask:` には入れず、mise task から
実 Homebrew の `brew trust --tap abue-ammar/tinycast` と
`brew install --cask abue-ammar/tinycast/tinycast` を実行する。

## Raycast の設定を Git で管理する

Raycast の **Settings → Advanced → Export** で設定を書き出し、出力されたファイルで
`dot_config/raycast/Raycast.rayconfig` を置き換えてコミットする。新しい Mac では
**Settings → Advanced → Import** から、chezmoi が配置した
`~/.config/raycast/Raycast.rayconfig` を読み込む。

```sh
cp ~/Downloads/Raycast.rayconfig \
  "$(chezmoi source-path)/dot_config/raycast/Raycast.rayconfig"
git -C "$(chezmoi source-path)" add dot_config/raycast/Raycast.rayconfig
git -C "$(chezmoi source-path)" commit -m "chore(raycast): update exported settings"
```

`.rayconfig` はバイナリのスナップショットであり、通常のテキスト diff や手編集には向かない。
設定変更後に再 export し、秘密情報を含めないことを確認して更新する。履歴・キャッシュなどの
Raycast の内部データディレクトリを丸ごと追跡するのではなく、公式の export/import を使う。

### export で管理できるもの

Raycast の export 画面で選択した次の項目を、この 1 ファイルとして管理できる。

- General、Appearance、Advanced などの環境設定
- グローバルおよび各コマンドのショートカット
- Extensions と各 Extension の設定
- Quicklinks、Snippets、Script Commands
- Floating Notes

アカウント認証、macOS の Accessibility などの権限、Raycast AI の履歴、クリップボード履歴、
キャッシュは、端末固有または機密性の高いデータであり、このバックアップの管理対象にしない。
export 時に表示される対象項目を確認し、API key、token、個人情報を含む Extension 設定は選択から
外す。Raycast のバージョンにより export 対象は変わりうるため、画面の一覧を正とする。

## 比較表

| 観点               | Raycast                                                                           | Tinycast                                                                                                     |
| ------------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 位置づけ           | 多機能な生産性ランチャー                                                          | 必要機能に絞った軽量な macOS ランチャー                                                                      |
| 実装・サイズ       | 独自アプリ。多数の組み込み機能とサービスを統合                                    | SwiftUI + AppKit、依存なし。公式 README では約 3 MB、RAM 100 MB 未満                                         |
| 基本機能           | アプリ検索、計算、Clipboard History、Snippets、Quicklinks、Window Management など | アプリ検索、計算・単位/通貨変換、Clipboard History、Snippets、カスタム shell command、Window Management など |
| 拡張               | Raycast Store の豊富な Extensions                                                 | Raycast Extensions を JavaScriptCore で実行し、SwiftUI で描画（互換性は Extension ごとに確認が必要）         |
| AI                 | Raycast AI（プランや設定に依存）                                                  | 組み込み AI 機能は公式 README に記載なし                                                                     |
| 同期・バックアップ | Raycast アカウントの Sync と `.rayconfig` の export/import                        | 読みやすい JSON の settings backup/import。Raycast の `.rayconfig` import にも対応                           |
| 設定を Git 管理    | `.rayconfig` は一括管理しやすいがバイナリで差分確認しにくい                       | JSON backup は差分確認しやすい。ただし権限同意、端末固有パス、Extension 実行許可などは意図的に対象外         |
| ライセンス         | プロプライエタリ                                                                  | AGPL-3.0 のオープンソース                                                                                    |
| macOS              | Raycast の現行要件に従う                                                          | macOS 15 Sequoia 用 cask と通常版を提供                                                                      |
| 向いている用途     | 完成度の高いエコシステム、AI、チーム/クラウド機能を重視                           | 小容量、低オーバーヘッド、オープンソース、ローカル中心を重視                                                 |

## Tinycast 側で Git 管理できる設定

Tinycast の **Settings → Backup** が出力する JSON は、設定、hotkey、custom command、
quicklink、お気に入りアプリ、非表示 launcher item、alias を保持する。clipboard の内容、notes、
snippets の本文、Extension 本体/設定は含まれない。また、安全上の理由から keystroke listening を
有効にする設定、第三者 JavaScript の実行許可、Extension registry、端末固有パス、画面上の位置、
入力ソースなども除外される。将来 Tinycast の backup も管理する場合は、この JSON を別途 export
して追跡し、コミット前に custom command や quicklink に秘密情報がないか確認する。

## 参考資料

- [Tinycast repository](https://github.com/abue-ammar/tinycast)
- [Tinycast settings backup implementation](https://github.com/abue-ammar/tinycast/blob/main/Tinycast/Features/Backup/Model/SettingsBackup.swift)
- [Raycast: Import & Export](https://manual.raycast.com/preferences/advanced#import-and-export)
