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
