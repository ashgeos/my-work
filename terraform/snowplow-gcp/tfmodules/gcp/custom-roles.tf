# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/google_project_iam_custom_role
resource "google_project_iam_custom_role" "pubsub-custom-role" {
  role_id     = "pubSubCustomRole"
  title       = "collector-enricher-pub-sub-role"
  description = "Role used by gke_service_account"
  permissions = ["iam.serviceAccounts.actAs", "pubsub.subscriptions.consume", "pubsub.subscriptions.create", "pubsub.subscriptions.get", "pubsub.subscriptions.list", "pubsub.topics.attachSubscription", "pubsub.topics.get", "pubsub.topics.list", "pubsub.topics.publish"]
}

resource "google_project_iam_custom_role" "composer-custom-role" {
  role_id     = "composerCustomRole"
  title       = "composer-custom-role"
  description = "Role used by composer_service_account"
  permissions = ["composer.environments.create", "iam.serviceAccounts.actAs"]
}
