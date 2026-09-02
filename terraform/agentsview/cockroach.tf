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

resource "cockroach_database" "agentsview" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = var.cockroach_database_name
}

resource "cockroach_sql_user" "owner" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_owner"
  password_wo         = var.cockroach_owner_password
  password_wo_version = var.cockroach_password_version
}

resource "cockroach_sql_user" "push" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_push"
  password_wo         = var.cockroach_push_password
  password_wo_version = var.cockroach_password_version
}

resource "cockroach_sql_user" "read" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_read"
  password_wo         = var.cockroach_read_password
  password_wo_version = var.cockroach_password_version
}
