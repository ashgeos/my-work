# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/composer_environment
resource "google_composer_environment" "composer_airflow" {
  name     = "${var.bu}-airflow-${var.environment}"
  project  = var.project_id
  region   = var.region
  provider = google-beta
  config {
    node_count = 3

    master_authorized_networks_config {
      enabled = "true"
      cidr_blocks {
        display_name = "Any"
        cidr_block   = "0.0.0.0/0"
      }
    }

    node_config {
      zone         = var.composer_cluster_zone
      machine_type = var.composer_machine_type

      network         = google_compute_network.composer_vpc.id
      subnetwork      = google_compute_subnetwork.composer_private.id
      disk_size_gb    = 120
      service_account = google_service_account.composer_service_account.name
    }

    software_config {
      #scheduler_count = 2 // only in Composer 1 with Airflow 2, use workloads_config in Composer 2
      image_version   = var.composer_airflow_image_version
      airflow_config_overrides = {
        core-dags_are_paused_at_creation = "True"
        core-store_serialized_dags = "True"
        core-min_serialized_dag_update_interval = "10"
        core-store_dag_code = "True"
        scheduler-dag_dir_list_interval = "10"
        webserver-rbac = "True"
        webserver-rbac_user_registration_role = "Admin"
      }
    }
    database_config {
      machine_type = var.composer_airflow_database_imachine_type
    }

    web_server_config {
      machine_type =var.composer_airflow_web_server_imachine_type
    }
  }
}
