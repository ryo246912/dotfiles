# `gcloud builds submit` がbuild contextを置くbucket。
#
# 名前はgcloudが既定で使う `<project-id>_cloudbuild` に固定する。ここを変えると
# gcloud側へ `--gcs-source-staging-dir` を渡す必要が出て、手元とCIの両方で
# build commandが分岐するためである。
#
# gcloud自身もこのbucketを作れるが、Terraformが持たないと「binding だけ書いて
# bucketが無い」状態でapplyが404になる。作成順を宣言できるようここで所有する。
resource "google_storage_bucket" "build_staging" {
  project  = var.gcp_project_id
  name     = "${var.gcp_project_id}_cloudbuild"
  location = "US"

  # 中身はbuildのたびに作られるsource tarballで、build後は参照されない。
  # 放置するとdeployの回数だけ積み上がるので30日で消す。
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  depends_on = [google_project_service.required]
}

# `gcloud builds submit` はsource tarballのuploadに先立ってbucketの存在確認
# （storage.buckets.get）も行うため、objectAdminではなくadminをこのbucketに限って
# 与える。project全体のstorage権限を与えるとTerraform state bucketまで読めてしまう。
resource "google_storage_bucket_iam_member" "deploy_build_staging" {
  bucket = google_storage_bucket.build_staging.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.deploy.email}"
}
