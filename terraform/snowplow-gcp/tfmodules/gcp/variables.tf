variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "gke_node_locations" {
  type = list(any)
}

variable "gke_service_account" {
  type = string
}

variable "composer_service_account" {
  type = string
}

variable "dbt_service_account" {
  type = string
}

variable "gke_cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "composer_machine_type" {
  type = string
}

variable "composer_cluster_zone" {
  type = string
}

variable "bq_dataset_location" {
  type = string
}

variable "gs_bucket_location" {
  type = string
}

variable "bu" {
  type = string
}

variable "composer_airflow_image_version" {
  type = string
} 

variable "composer_airflow_database_imachine_type" {
  type = string
}

variable "composer_airflow_web_server_imachine_type" {
  type = string
}