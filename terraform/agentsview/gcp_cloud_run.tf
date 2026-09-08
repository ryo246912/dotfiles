# Cloud Run service本体はここで管理しない。clrndが
# dot_config/agentsview/cloudrun-service.yaml から所有する。Terraformに持たせると
# clrndのdeployをすべてdriftとして戻してしまい、revisionが失敗したときには
# bootstrap中に実際に踏んだtaint／replaceの詰みに繋がる。
#
# IAMはclrndの管理範囲外なので、公開用のinvoker bindingだけTerraformに残す。
# Cloud Run resourceではなくservice名とregionで指すため、このrootはCloud Runの
# stateに依存しない。
#
# 順序: clrndがserviceを作ってからでないとこのbindingは付けられない。
# 詳細は docs/agentsview.md を参照。
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.gcp_project_id
  location = local.region
  name     = local.cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_project_service.required]
}
