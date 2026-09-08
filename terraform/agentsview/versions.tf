terraform {
  required_version = ">= 1.11.0"

  required_providers {
    cockroach = {
      source  = "cockroachdb/cockroach"
      version = "~> 1.22"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # bucket／prefixはinit時に渡す。このdirectoryにaccount IDを残さないためである。
  # terraform init -backend-config="bucket=..." -backend-config="prefix=agentsview"
  backend "gcs" {}
}
