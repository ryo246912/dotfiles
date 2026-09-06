provider "google" {
  project = var.gcp_project_id
  region  = local.region
}

# Authentication is read from COCKROACH_API_KEY. Do not put the API key in a
# tfvars file or Terraform state.
provider "cockroach" {}
