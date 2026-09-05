locals {
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

data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}
