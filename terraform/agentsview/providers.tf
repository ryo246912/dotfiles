provider "google" {
  project = var.gcp_project_id
  region  = local.region
}

# 認証情報は COCKROACH_API_KEY から読む。API keyをtfvarsやTerraform stateへ
# 書かないこと。
provider "cockroach" {}
