# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_policy" "snowplow_project_iam" {
  project     = var.project_id
  policy_data = data.google_iam_policy.newsid_snowplow_policy.policy_data
  lifecycle {
    prevent_destroy = true
  }
}

data "google_iam_policy" "newsid_snowplow_policy" {
  binding {
    role = "roles/owner"
    members = [
      "user:ashish.george@ntsindia.co.in",
      "serviceAccount:terraform@dj-nct-cse-prod-tools.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/cloudbuild.builds.builder"
    members = [
      "serviceAccount:43903253783@cloudbuild.gserviceaccount.com"
    ]
  } 

  binding {
    role = "roles/composer.serviceAgent"
    members = [
      "serviceAccount:service-43903253783@cloudcomposer-accounts.iam.gserviceaccount.com"
    ]
  }  
 
  binding {
    role = "roles/compute.serviceAgent"
    members = [
      "serviceAccount:service-43903253783@compute-system.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/cloudbuild.serviceAgent"
    members = [
      "serviceAccount:service-43903253783@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/container.serviceAgent"
    members = [
      "serviceAccount:service-43903253783@container-engine-robot.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/containerregistry.ServiceAgent"
    members = [
      "serviceAccount:service-43903253783@containerregistry.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/pubsub.serviceAgent"
    members = [
      "serviceAccount:service-43903253783@gcp-sa-pubsub.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/editor"
    members = [
      "serviceAccount:${var.composer_service_account}@${var.project_id}.iam.gserviceaccount.com",
      "serviceAccount:43903253783-compute@developer.gserviceaccount.com",
      "serviceAccount:43903253783@cloudservices.gserviceaccount.com"
    ]
  }


  binding {
    role = "roles/bigquery.admin"
    members = [
      "serviceAccount:${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com",
      "serviceAccount:${var.dbt_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/monitoring.admin"
    members = [
      "serviceAccount:${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/storage.objectViewer"
    members = [
      "serviceAccount:${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/compute.admin"
    members = [
      "serviceAccount:${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/composer.worker"
    members = [
      "serviceAccount:${var.composer_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/monitoring.viewer"
    members = [
      "serviceAccount:${var.composer_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:${var.composer_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${var.dbt_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "projects/${var.project_id}/roles/pubSubCustomRole"
    members = [
      "serviceAccount:${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }

  binding {
    role = "projects/${var.project_id}/roles/composerCustomRole"
    members = [
      "serviceAccount:${var.composer_service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }
}

resource "google_project_iam_audit_config" "project_storage_audit_config" {
  project = var.project_id
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_audit_config" "project_composer_audit_config" {
  project = var.project_id
  service = "composer.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_audit_config" "project_compute_audit_config" {
  project = var.project_id
  service = "compute.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_audit_config" "project_secretmanager_audit_config" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

resource "google_project_iam_audit_config" "project_container_audit_config" {
  project = var.project_id
  service = "container.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_audit_config" "project_iam_audit_config" {
  project = var.project_id
  service = "iam.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}