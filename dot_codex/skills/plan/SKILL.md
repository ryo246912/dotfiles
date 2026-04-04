---
name: plan
description: plan/ artifact を分離して扱う skill。spec 整理、調査、計画、実装記録、テスト記録に使う。
---
# plan skill

`plan/` ディレクトリをこの workflow の唯一の記録場所として扱います。phase をまたぐときは、必ず対応する artifact を更新してから次に進みます。

## 生成・更新する artifact

| ファイル | 役割 |
| --- | --- |
| `plan/00-search.md` | 調査結果、外部仕様メモ、比較結果 |
| `plan/00-spec.md` | ユーザーが書く仕様の正本。未作成なら現時点の要件から草案を作り、仮定を明記する |
| `plan/01-plan.md` | 標準の実装計画 |
| `plan/01-plan-<slug>.md` | 代替案やフェーズ別 plan が必要なときの追加計画 |
| `plan/02-implement.md` | 実装で実際に行った変更、判断、差分サマリ |
| `plan/03-test.md` | 実施した検証、未実施の確認項目、再現手順 |
| `plan/99-instrucemt.md` | ユーザーから受け取ったファイルベースの指示や制約の転記 |

`99-instrucemt.md` は ticket 記載の綴りに合わせて扱います。勝手に改名しません。

## phase の境界

### `/plan`

- 実装はしません。
- `00-spec.md` と `99-instrucemt.md` を整理し、`01-plan.md` または `01-plan-<slug>.md` に実装計画だけを書きます。
- 不明点や追加調査が必要なら `00-search.md` に TODO を残します。

### `/plan:search`

- 調査だけを行います。
- 調査結果を `00-search.md` に追記します。
- 実装・apply・コミットはしません。
- 調査で計画に影響が出た場合だけ `01-plan*.md` に差分を反映します。

### `/plan:implement`

- `00-spec.md`, `99-instrucemt.md`, 最新の `01-plan*.md`, 必要なら `00-search.md` を読んでから実装します。
- 実装内容は `02-implement.md` に、検証手順と結果は `03-test.md` に残します。
- 計画にない作業が必要になった場合は、先に `01-plan*.md` を更新してから実装へ戻ります。

## 基本手順

1. `plan/` がなければ作成します。
2. ユーザーがファイルや既存文書を参照したら、その要点を `99-instrucemt.md` に転記します。
3. `00-spec.md` を基準に作業範囲を決めます。仕様が未確定なら仮定を明記します。
4. 調査は `00-search.md`、計画は `01-plan*.md`、実装は `02-implement.md`、検証は `03-test.md` に分離します。
5. phase を越えるたびに、対応する artifact を更新してから応答します。

## 実装時のルール

- `/plan` と `/plan:search` ではコード変更をしません。
- `/plan:implement` では、何を変えたか・なぜそうしたか・どう検証したかを必ず文書化します。
- 複数案を比較する場合は `01-plan-<slug>.md` を増やし、`01-plan.md` を無理に肥大化させません。
- 返答では、どの artifact を更新したかを明示します。
