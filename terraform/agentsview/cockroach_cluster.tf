resource "cockroach_cluster" "agentsview" {
  name           = var.cockroach_cluster_name
  cloud_provider = "GCP"
  plan           = "BASIC"
  serverless = {
    usage_limits = {
      request_unit_limit = 50000000
      storage_mib_limit  = 10240
    }
  }
  regions = [{
    name = var.cockroach_region
  }]

  delete_protection = true
  labels = {
    application = "agentsview"
    environment = "production"
    managed-by  = "terraform"
  }
}
