locals {
  # AgentsViewの運用に必要なAPIだけを有効化する。sts／iamcredentialsは
  # GitHub ActionsのWorkload Identity連携（gcp_iam.tf）が使う。
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sts.googleapis.com",
  ])
}

# Cloud Buildの既定service accountを組み立てるためにproject numberが要る。
data "google_project" "current" {
  project_id = var.gcp_project_id
}

# disable_on_destroy = false: このrootを壊してもAPIは有効なまま残す。ほかの
# resourceが同じAPIに依存している可能性があるため、無効化まではしない。
resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}
