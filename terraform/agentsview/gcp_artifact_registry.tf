resource "google_artifact_registry_repository" "agentsview" {
  project       = var.gcp_project_id
  location      = local.region
  repository_id = "agentsview"
  description   = "AgentsView Cloud Run images"
  format        = "DOCKER"

  # Artifact Registryの無料枠はproject／月あたり0.5 GBしかない。imageのtagは
  # commitごとに変わるので、deployを重ねるほどversionが積み上がり、mergeごとに
  # deployするGitHub Actionsを足すとその速度が上がる。
  #
  # KEEPはDELETEより優先されるので、直近10 versionはolder_thanに関係なく残る。
  # この10という数はrollbackの上限でもある。Cloud Runはmin 0でscale-to-zeroする
  # ため、cold startのたびにimageをpullし直す。稼働中またはrollback先のrevisionが
  # 参照するimageを消すと、そのrevisionはinstanceを起動できなくなる。deployより
  # 10世代前まで戻せれば足りるという判断で、それより古いものだけを消す。
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-versions"
    action = "DELETE"

    condition {
      older_than = "2592000s" # 30日
    }
  }

  depends_on = [google_project_service.required]
}

# Cloud Runのrevisionがimageをpullするために必要。
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

# `gcloud builds submit` が使うidentityは、projectの作成時期とpolicyによって
# 旧Cloud Build用とCompute Engine既定のどちらになるか変わる。どちらでもbuild結果を
# push できるよう両方へ権限を付ける。
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  for_each = local.cloud_build_service_accounts

  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}
