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

resource "google_artifact_registry_repository" "agentsview" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "agentsview"
  description   = "AgentsView Cloud Run images"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = "agentsview-runtime"
  display_name = "AgentsView Cloud Run runtime"
}

resource "google_service_account" "deploy" {
  project      = var.gcp_project_id
  account_id   = "agentsview-deploy"
  display_name = "AgentsView GitHub Actions deploy"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.gcp_project_id
  workload_identity_pool_id = var.github_wif_pool_id
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "dotfiles"
  display_name                       = "dotfiles GitHub Actions"
  attribute_condition                = "assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/main'"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.ref"        = "assertion.ref"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_deploy" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

locals {
  deploy_project_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ])
}

resource "google_project_iam_member" "deploy" {
  for_each = local.deploy_project_roles

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_service_account_iam_member" "deploy_uses_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_secret_manager_secret" "pg_url" {
  project   = var.gcp_project_id
  secret_id = "agentsview-pg-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "config" {
  project   = var.gcp_project_id
  secret_id = "agentsview-config-toml"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_iam_member" "runtime_pg_url" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.pg_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "runtime_config" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.config.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_artifact_registry_repository_iam_member" "runtime_reader" {
  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

locals {
  cloud_build_service_accounts = toset([
    "${data.google_project.current.number}@cloudbuild.gserviceaccount.com",
    "${data.google_project.current.number}-compute@developer.gserviceaccount.com",
  ])
}

# Google Cloud projects can use either the legacy Cloud Build identity or the
# Compute Engine default identity for builds, depending on project age/policy.
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  for_each = local.cloud_build_service_accounts

  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}

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
