# Raycast と代替ランチャー

## 運用方針

メインランチャーには Vicinae を使用し、macOS bootstrap の `brew-cask:vicinae` で導入する。
Vicinae の設定は `dot_config/vicinae/settings.json` を正本として chezmoi で管理する。

Raycast と Tinycast は bootstrap でインストールしない。Raycast の export は移行前の設定値を
参照・保管する目的で `dot_config/raycast/` に残すが、通常のセットアップでは import しない。
Tinycast は比較対象としてのみ記録する。

## 比較表

| 観点                                                  | Raycast                                                                                                       | Tinycast                                                                                                                                                                                           | Vicinae                                                                                                                                    |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 位置づけ                                              | 多機能な macOS 生産性ランチャー                                                                               | SwiftUI + AppKit 製の macOS 専用ランチャー                                                                                                                                                         | Qt/C++ 製の macOS/Linux/Windows 向けランチャー                                                                                             |
| 軽量性                                                | 比較の基準                                                                                                    | 公式 README が「100 MB 未満の RAM」「サードパーティ依存なし」を明記                                                                                                                                | 公式 README は native/high-performance とするが、Raycast より軽量だと判断できる公称 RAM 値や同条件ベンチマークはない                       |
| 基本機能                                              | アプリ/ファイル検索、計算、Clipboard History、Snippets、Quicklinks、Window Management、ブラウザータブ検索など | アプリ/ファイル検索、計算、Clipboard History、Snippets、Quicklinks、Window Management、Calendar、Notes など                                                                                        | アプリ/ファイル検索、計算、Clipboard History、Snippets、Quicklinks、Window/Workspace、ブラウザータブ検索など                               |
| Raycast Extension                                     | 公式ランタイム/Store                                                                                          | 独自の JavaScriptCore shim。実機調査では view command 147 個中 114 個が描画できたとしており、完全互換ではない                                                                                      | React/TypeScript Extension と Raycast Store を統合する互換ランタイム。完全互換の保証ではない                                               |
| Script Commands                                       | 対応                                                                                                          | custom shell command はあるが、Raycast Script Commands 互換としては案内されていない                                                                                                                | Raycast Script Commands 互換                                                                                                               |
| AI                                                    | Raycast AI（今回は評価対象外）                                                                                | 任意。BYOK/ローカル CLI 連携で、初期状態は無効                                                                                                                                                     | 組み込み AI は公式の機能一覧にない                                                                                                         |
| 設定の Git 管理                                       | `.rayconfig` はバイナリで diff/手編集不可                                                                     | `.tinycast` は archive。その内部は JSON/JSONL/Markdown だが、そのままでは通常の Git diff/手編集に不向き                                                                                            | `~/.config/vicinae/settings.json` が正本。GUI の変更も JSON に反映され、`imports` でファイル分割可能。password preference は書き込まれない |
| Raycast 設定の移行                                    | 不要                                                                                                          | `.rayconfig` の import に対応。ただし全項目の移行を保証しない                                                                                                                                      | `.rayconfig` の一括 import は公式文書に記載がないため、JSON を作り直す                                                                     |
| 同期                                                  | Raycast アカウントの Sync                                                                                     | クラウド同期なし。JSON を自分で同期                                                                                                                                                                | クラウド同期なし。設定 JSON を自分で同期                                                                                                   |
| ライセンス                                            | プロプライエタリ                                                                                              | AGPL-3.0                                                                                                                                                                                           | GPL-3.0                                                                                                                                    |
| **Raycast にはあり、本ツールにはない/制限があるもの** | —                                                                                                             | Raycast Sync/Teams、Store Extension の完全互換、Extension の `menu-bar` command、Raycast OAuth proxy、WebSocket/一部 Node API、Extension からの Raycast AI・BrowserExtension・WindowManagement API | Raycast Sync/Teams、`.rayconfig` 一括 import、Raycast AI。macOS 固有 API や未実装 API を使う Extension は個別確認が必要                    |

「互換」は Raycast Store の全 Extension が動くという意味ではない。特に Tinycast は[未対応 API を明記](https://github.com/abue-ammar/tinycast/blob/main/docs/features/extensions.md#what-isnt-supported-yet)している。
Vicinae も [Raycast API 互換レイヤー](https://docs.vicinae.com/extensions/introduction) で実行するため、使用中の Extension ごとに動作確認する。

## Tinycast 側で Git 管理できる設定

Tinycast の **Settings → Backup** は、選択した Settings & Shortcuts、Clipboard History、Snippets、
Notes、Launcher Learning を 1 個の `.tinycast` archive に出力する。内部は JSON、JSONL、Markdown
だが、archive のままでは通常のテキスト diff はできない。Extension、AI chat history、Keychain、
cache は含まれず、keystroke listening や第三者コード実行など capability を有効にする設定も
安全上の理由から除外される。追跡する場合は秘密情報を確認し、archive を opaque backup として
扱う。内部ファイルを展開して編集しても、アプリへ直接適用できる設定の正本にはならない。

## Vicinae 側で Git 管理できる設定

Vicinae は `~/.config/vicinae/settings.json` を直接読み書きする。GUI で設定した keybind、theme、
favorite、fallback、provider/entrypoint 設定なども同ファイルへ反映される。`imports` を使えば、
例えば keybind と provider を別 JSON に分けて chezmoi 管理できる。password preference、履歴、
cache、Extension 本体などは設定ファイルとは別であり、秘密情報や生成データを追跡しない。

## 参考資料

- [Tinycast repository](https://github.com/abue-ammar/tinycast)
- [Tinycast backup format](https://github.com/abue-ammar/tinycast/blob/main/docs/features/backup.md)
- [Tinycast Raycast Extension runtime](https://github.com/abue-ammar/tinycast/blob/main/docs/features/extensions.md)
- [Vicinae repository](https://github.com/vicinaehq/vicinae)
- [Vicinae default configuration](https://github.com/vicinaehq/vicinae/blob/main/extra/config.jsonc)
- [Vicinae extensions](https://docs.vicinae.com/extensions/introduction)
- [Raycast: Import & Export](https://manual.raycast.com/import-export)
