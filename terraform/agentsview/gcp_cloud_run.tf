# The Cloud Run service itself is NOT managed here: clrnd owns it, from the
# manifest at dot_config/agentsview/cloudrun-service.yaml. Terraform would
# otherwise revert every clrnd deploy as drift, and a failed revision would turn
# into the taint/replacement conflict this root hit during bootstrap.
#
# IAM is outside what clrnd manages, so the public invoker binding stays in
# Terraform. It refers to the service by name and region rather than to a
# Terraform resource, so nothing here depends on Cloud Run state.
#
# Ordering: clrnd creates the service (private) before this binding can be
# applied. See docs/agentsview.md.
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.gcp_project_id
  location = local.region
  name     = var.cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_project_service.required]
}
