# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/compute_router
resource "google_compute_router" "gke_router" {
  name    = "${var.project_id}-router"
  region  = var.region
  network = google_compute_network.gke_vpc.id
}

resource "google_compute_router" "composer_router" {
  name    = "${var.project_id}-composer-router"
  region  = var.region
  network = google_compute_network.composer_vpc.id
}
