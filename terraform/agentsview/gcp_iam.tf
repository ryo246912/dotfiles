# Cloud Runのrevisionが名乗るidentity。Secret Managerの2つのsecretを読み、
# Artifact Registryからimageをpullできる。deployはできない。
resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = "agentsview-runtime"
  display_name = "AgentsView Cloud Run runtime"

  depends_on = [google_project_service.required]
}
