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

  # Pass bucket/prefix at init time so this directory contains no account IDs:
  # terraform init -backend-config="bucket=..." -backend-config="prefix=agentsview"
  backend "gcs" {}
}
