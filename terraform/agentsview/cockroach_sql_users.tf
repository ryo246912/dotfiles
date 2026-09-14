# CockroachDB Cloudが作るSQL userは初期状態でadmin roleに属する。最小権限は
# providerでは表現できないため、作成後に `mise run agentsview:cockroach:configure-roles`
# でadminをREVOKEし、role別のGRANTを設定する。
#
# passwordを意図的に指定していない。指定するとTerraformがresource attributeを
# binary plan fileへ平文で埋め込む（sensitive指定はCLI出力とJSON構造化出力を
# マスクするだけで、planファイル自体には効かない）。このrepositoryは公開repoで、
# tfactionはplan fileをGitHub Artifactsへ上げるため、指定するとsign-inした
# 任意のGitHub userがpasswordをdownloadできてしまう。
# passwordを省略すると、providerがcluster作成時にrandom passwordを生成した上で
# 破棄し、Terraformの管理下（plan file・state）に一切残さない。実際に使う
# passwordは `mise run agentsview:cockroach:set-passwords` がCockroachDB
# Cloud APIを直接呼んで別途設定する（terraform/agentsview/tfaction.yamlの
# secretsにこの3つのpasswordを含めていないのもこのため）。
#
# TODO(password_wo): cockroachdb/terraform-provider-cockroachのwrite-only
# 属性 password_wo／password_wo_version が正式releaseされたら、上記コメントと
# `mise run agentsview:cockroach:set-passwords` taskを削除し、
# 次のように書き換えてpassword管理をTerraform内だけで完結させる。
#   password_wo         = var.cockroach_owner_password_wo # sensitive変数
#   password_wo_version = 1                                # rotateする度に+1
# password_woもstate／plan fileに値を一切残さないため、この設計上の理由は
# 解消される。2026-09-14時点ではcockroachdb/terraform-provider-cockroachの
# mainブランチにのみ存在し（CHANGELOG.mdのUnreleased節）、versions.tfが
# 参照する最新release v1.22.0には含まれていない。
resource "cockroach_sql_user" "owner" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_owner"
}

resource "cockroach_sql_user" "push" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_push"
}

resource "cockroach_sql_user" "read" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_read"
}
