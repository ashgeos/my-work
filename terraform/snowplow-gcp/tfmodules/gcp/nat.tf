# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/compute_router_nat
# NAT for GKE VPC we created.
resource "google_compute_router_nat" "gke_nat" {
  name   = "${var.project_id}-nat"
  router = google_compute_router.gke_router.name
  region = var.region

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "AUTO_ONLY"

  subnetwork {
    name                    = google_compute_subnetwork.gke_private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}


# NAT for Composer VPC we created.
resource "google_compute_router_nat" "composer_nat" {
  name   = "${var.project_id}-composer-nat"
  router = google_compute_router.composer_router.name
  region = var.region

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "AUTO_ONLY"

  subnetwork {
    name                    = google_compute_subnetwork.composer_private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
