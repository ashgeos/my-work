# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/google_service_account
resource "google_service_account" "gke_service_account" {
  account_id   = var.gke_service_account
  display_name = var.gke_service_account
  description  = "This service account is specially for GKE Snowplow Cluster"
}

resource "google_service_account" "composer_service_account" {
  account_id   = var.composer_service_account
  display_name = var.composer_service_account
  description  = "This service account is specially for GCP cloud composer"
}

resource "google_service_account" "dbt_service_account" {
  account_id   = var.dbt_service_account
  display_name = var.dbt_service_account
  description  = "This Service Account Mainly used for snowplow DBT"
}
