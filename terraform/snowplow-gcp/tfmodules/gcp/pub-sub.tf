# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/pubsub_topic
resource "google_pubsub_topic" "raw_good" {
  name                       = "${var.bu}-ncg-${var.environment}-raw-good"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "raw_bad" {
  name                       = "${var.bu}-ncg-${var.environment}-raw-bad"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "enriched_good" {
  name                       = "${var.bu}-ncg-${var.environment}-enriched-good"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "enriched_bad" {
  name                       = "${var.bu}-ncg-${var.environment}-enriched-bad"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "loader_types" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-types"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "loader_deadletter" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-deadletter"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_topic" "loader_bad_rows" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-bad-rows"
  project                    = var.project_id
  message_retention_duration = "259200s"
}

resource "google_pubsub_subscription" "raw_good_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-raw-good-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.raw_good.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "raw_bad_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-raw-bad-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.raw_bad.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "enriched_good_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-enriched-good-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.enriched_good.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "enriched_bad_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-enriched-bad-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.enriched_bad.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "loader_types_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-types-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.loader_types.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "loader_deadletter_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-deadletter-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.loader_deadletter.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}

resource "google_pubsub_subscription" "loader_bad_rows_sub" {
  name                       = "${var.bu}-ncg-${var.environment}-loader-bad-rows-sub"
  project                    = var.project_id
  topic                      = google_pubsub_topic.loader_bad_rows.name
  message_retention_duration = "259200s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 10
  enable_message_ordering    = false
}