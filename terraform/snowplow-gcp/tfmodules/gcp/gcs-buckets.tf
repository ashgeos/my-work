# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/storage_bucket#nested_action
resource "google_storage_bucket" "sp-tracker" {
  name          = "${var.bu}-ncg-${var.environment}-sp-tracker"
  project       = var.project_id
  location      = var.gs_bucket_location
  storage_class = "STANDARD"
  force_destroy = "false"
}

resource "google_storage_bucket" "dead-letter-bucket" {
  name          = "${var.bu}-ncg-${var.environment}-dead-letter-bucket"
  project       = var.project_id
  location      = var.gs_bucket_location
  storage_class = "STANDARD"
  force_destroy = "false"
}

resource "google_storage_bucket" "iglu-schemas" {
  name          = "${var.bu}-ncg-${var.environment}-iglu-schemas"
  project       = var.project_id
  location      = var.gs_bucket_location
  storage_class = "STANDARD"
  force_destroy = "false"
}

resource "google_storage_bucket" "enricher-db" {
  name          = "${var.bu}-ncg-${var.environment}-enricher-db"
  project       = var.project_id
  location      = var.gs_bucket_location
  storage_class = "STANDARD"
  force_destroy = "false"
}