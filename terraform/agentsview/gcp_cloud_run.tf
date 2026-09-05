resource "google_cloud_run_v2_service" "agentsview" {
  project             = var.gcp_project_id
  location            = var.gcp_region
  name                = var.cloud_run_service_name
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = true

  template {
    service_account = google_service_account.runtime.email
    timeout         = "60s"

    max_instance_request_concurrency = 20

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.agentsview_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "PG_SERVE"
        value = "1"
      }

      env {
        name  = "AGENTSVIEW_DISABLE_UPDATE_CHECK"
        value = "1"
      }

      env {
        name  = "AGENTSVIEW_PG_SCHEMA"
        value = "agentsview"
      }

      env {
        name = "AGENTSVIEW_PG_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pg_url.secret_id
            version = var.pg_url_secret_version
          }
        }
      }

      volume_mounts {
        name       = "config"
        mount_path = "/data"
      }
    }

    volumes {
      name = "config"
      secret {
        secret = google_secret_manager_secret.config.secret_id
        items {
          version = var.config_secret_version
          path    = "config.toml"
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository_iam_member.runtime_reader,
    google_secret_manager_secret_iam_member.runtime_config,
    google_secret_manager_secret_iam_member.runtime_pg_url,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.gcp_project_id
  location = google_cloud_run_v2_service.agentsview.location
  name     = google_cloud_run_v2_service.agentsview.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
