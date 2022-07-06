# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "gke_cluster" {
  name                     = var.gke_cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.gke_vpc.self_link
  subnetwork               = google_compute_subnetwork.gke_private.self_link
  #logging_service          = "logging.googleapis.com/kubernetes"
  #monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode = "VPC_NATIVE"

  # Optional, if you want multi-zonal cluster
  node_locations = var.gke_node_locations

  addons_config {
    horizontal_pod_autoscaling {
      disabled = true
    }
  }
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  release_channel {
    channel = "REGULAR"
  }

  master_authorized_networks_config {
    cidr_blocks {
      display_name = "Any"
      cidr_block   = "0.0.0.0/0"
    }
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.project_id}-pods"
    services_secondary_range_name = "${var.project_id}-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}
