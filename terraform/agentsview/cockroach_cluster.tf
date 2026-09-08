# 無料枠内に収めるためusage limitを明示する。上限に達すると課金ではなく
# throttleされる。delete_protection は誤destroyでsessionを失わないための保険。
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
    name = local.region
  }]

  delete_protection = true
  labels = {
    application = "agentsview"
    environment = "production"
    managed-by  = "terraform"
  }
}
