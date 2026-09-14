# Raycast と代替ランチャー

> [!NOTE]
> この比較は 2026-09-14 時点の各プロジェクトの公式文書・実装に基づく。
> 開発中の互換ランタイムは変化が速いため、移行前に使用中の Extension を実機で確認する。

## インストール

macOS のパッケージ bootstrap で Raycast と Tinycast を導入する。

```sh
mise run bootstrap:mac-packages
```

Tinycast は公式 tap の cask を利用する。サードパーティ tap の Homebrew API メタデータが
公開されていないため、`[bootstrap.packages]` の `brew-cask:` には入れず、mise task から
完全修飾した cask 名を指定して `brew install --cask abue-ammar/tinycast/tinycast` を実行する。

Vicinae は比較対象に留め、現時点では bootstrap に追加しない。採用する場合は
[公式 Releases](https://github.com/vicinaehq/vicinae/releases) の macOS 用 DMG を利用する。

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

「互換」は Raycast Store の全 Extension が動くという意味ではない。特に Tinycast は
[未対応 API を明記](https://github.com/abue-ammar/tinycast/blob/main/docs/features/extensions.md#what-isnt-supported-yet)
している。Vicinae も [Raycast API 互換レイヤー](https://docs.vicinae.com/extensions/introduction) で
実行するため、使用中の Extension ごとに動作確認する。

## 結論: Vicinae を移行候補として実測する

3 条件を公式情報だけで同時に満たすと断定できる製品はない。**移行候補は Vicinae** とし、
Raycast と同条件でメモリーを実測してから採用を確定する。

1. **テキスト設定**: Vicinae だけが、アプリが直接読み書きする設定の正本を JSON として管理できる。
   Tinycast の backup は内部データこそテキストだが、成果物は `.tinycast` archive である。
2. **軽量性**: Vicinae は native/high-performance を掲げるが、Raycast との同条件ベンチマークはない。
   したがって、ここだけは実機の Activity Monitor で合否を判定する。
3. **Extension 互換**: Vicinae は Raycast Store をアプリ内に統合し、Raycast Extension と
   Script Commands の互換を公式に掲げる。ただし全 Extension の完全互換ではない。
4. **AI 不要**: AI を使わない今回の用途では、Raycast AI の有無は選定を左右しない。

軽量性の実測で Raycast を下回らなければ採用を見送り、次点の Tinycast を試す。Tinycast は
公式に RAM 100 MB 未満を掲げ、`.rayconfig` import も備える一方、設定ファイルをそのまま
dotfiles としてレビューする要件には劣る。この優先順位なら、検証結果にかかわらず条件を
暗黙に緩めずに済む。

### 移行手順

1. Vicinae の macOS DMG を導入し、Raycast と同じログイン直後・同じ Extension 構成で、
   Activity Monitor の Memory と CPU を比較する。
2. `~/.config/vicinae/settings.json` を chezmoi に追加し、設定 UI の変更が意図どおり diff になる
   ことを確認する。password preference は別途安全に再設定する。
3. Raycast の Quicklinks、Snippets、Script Commands、keybind を JSON/ファイルへ手動で移す。
4. 日常的に使う Raycast Extension を 1 つずつ Raycast Store から導入し、macOS 固有 API、OAuth、
   menu-bar command を使うものを重点的に確認する。
5. 1 週間併用し、機能欠落がなく、実測メモリーが Raycast 未満なら Raycast の自動起動を止める。

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
- [Raycast: Import & Export](https://manual.raycast.com/preferences/advanced#import-and-export)
