# 実行計画: Terraform Debug用Abbreviationの追加

## 1. 目的
Terraformのデバッグログを簡単に出力できるように、`zabrze` の設定を拡張し、新しい略称（abbr）を追加します。

## 2. 追加する略称の提案
以下の命名規則に基づき、`plan` と `apply` に対してそれぞれ3種類（全体、Coreのみ、Providerのみ）の略称を追加します。
末尾を `d` に統一するというルールに従います。

### Terraform Plan
| 略称 | 展開されるコマンド | 説明 |
| :--- | :--- | :--- |
| `tfpd` | `TF_LOG=DEBUG terraform plan` | 全体のデバッグログを出力 |
| `tfpcd` | `TF_LOG_CORE=DEBUG terraform plan` | Terraform Coreのみのデバッグログを出力 |
| `tfppd` | `TF_LOG_PROVIDER=DEBUG terraform plan` | Providerのみのデバッグログを出力 |

### Terraform Apply
| 略称 | 展開されるコマンド | 説明 |
| :--- | :--- | :--- |
| `tfad` | `TF_LOG=DEBUG terraform apply` | 全体のデバッグログを出力 |
| `tfacd` | `TF_LOG_CORE=DEBUG terraform apply` | Terraform Coreのみのデバッグログを出力 |
| `tfapd` | `TF_LOG_PROVIDER=DEBUG terraform apply` | Providerのみのデバッグログを出力 |

## 3. 実施手順
1. `dot_config/zabrze/terraform.toml` に上記のスニペット定義を追加する。
2. 変更内容が正しいかファイル内容を確認する。
3. `pre_commit_instructions` に従い、最終確認を行う。

## 4. 期待される効果
- デバッグが必要な際、長い環境変数を入力する手間が省ける。
- CoreとProviderのログを切り分けることで、必要な情報に素早くアクセスできるようになる。
