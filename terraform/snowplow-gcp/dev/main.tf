provider "google" {
  project = "ashish-snowplow-project"
  region  = "us-central1"
}

provider "google-beta" {
  project = "ashish-snowplow-project"
  region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "terraform-state-dev"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.25.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.25.0"
    }
  }
}

module "gcp" {
  source                                    = "../tfmodules/gcp"
  project_id                                = "ashish-snowplow-project"
  region                                    = "us-central1"
  gke_service_account                       = "compute-engine"
  composer_service_account                  = "cloud-composer"
  dbt_service_account                       = "snowplow-dbt"
  gke_cluster_name                          = "snowplow-cluster-dev"
  gke_node_locations                        = ["us-central1-a", "us-central1-b", "us-central1-c"]
  machine_type                              = "e2-highcpu-8"
  gs_bucket_location                        = "US"
  bu                                        = "nypost"
  environment                               = "dev"
  bq_dataset_location                       = "US"
  composer_cluster_zone                     = "us-central1-c"
  composer_machine_type                     = "n1-standard-2"
  composer_airflow_image_version            = "composer-1.18.0-airflow-1.10.15"
  composer_airflow_database_imachine_type   = "db-n1-standard-2"
  composer_airflow_web_server_imachine_type = "composer-n1-webserver-2"
}

module "iam-dev" {
  source                   = "../tfmodules/gcp/iam-dev"
  project_id               = "ashish-snowplow-project"
  gke_service_account      = "compute-engine"
  composer_service_account = "cloud-composer"
  dbt_service_account      = "snowplow-dbt"
}