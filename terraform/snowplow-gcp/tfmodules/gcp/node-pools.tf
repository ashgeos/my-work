# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/container_node_pool
resource "google_container_node_pool" "snowplow" {
  name       = "snowplow-pool"
  cluster    = google_container_cluster.gke_cluster.id
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 15
  }
  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
  }
  node_config {
    preemptible  = false
    machine_type = var.machine_type

    service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
