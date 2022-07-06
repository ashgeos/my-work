# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "gke_private" {
  name                     = "${var.project_id}-private"
  ip_cidr_range            = "10.21.4.0/24"
  region                   = var.region
  network                  = google_compute_network.gke_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${var.project_id}-pods"
    ip_cidr_range = "10.68.0.0/14"
  }
  secondary_ip_range {
    range_name    = "${var.project_id}-services"
    ip_cidr_range = "10.72.0.0/20"
  }
}


resource "google_compute_subnetwork" "composer_private" {
  name                     = "${var.project_id}-composer-private"
  ip_cidr_range            = "10.61.0.0/20"
  region                   = var.region
  network                  = google_compute_network.composer_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${var.project_id}-pods"
    ip_cidr_range = "10.20.0.0/20"
  }
  secondary_ip_range {
    range_name    = "${var.project_id}-services"
    ip_cidr_range = "10.16.0.0/14"
  }
}