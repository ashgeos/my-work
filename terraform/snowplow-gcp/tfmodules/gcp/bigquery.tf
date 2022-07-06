# https://registry.terraform.io/providers/hashicorp/google/4.25.0/docs/resources/bigquery_dataset
resource "google_bigquery_dataset" "datalake_cdm" {
  project     = var.project_id
  dataset_id  = "datalake_cdm"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "datalake_bdm_intermediate" {
  project     = var.project_id
  dataset_id  = "datalake_bdm_intermediate"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "datalake_bdm" {
  project     = var.project_id
  dataset_id  = "datalake_bdm"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "datalake_scratchpad" {
  project     = var.project_id
  dataset_id  = "datalake_scratchpad"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "newsid_pixel_seed" {
  project     = var.project_id
  dataset_id  = "newsid_pixel_seed"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "datalake_seed_data" {
  project     = var.project_id
  dataset_id  = "datalake_seed_data"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_dataset" "newsid_prod" {
  project     = var.project_id
  dataset_id  = "newsid_prod"
  location    = var.bq_dataset_location
  description = "This dataset is used by populate_datalake_v2 DAG"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_bigquery_table" "datalake_cdm_good_events" {
  project    = var.project_id
  table_id   = "good_events"
  dataset_id = google_bigquery_dataset.datalake_cdm.dataset_id
  schema     = file("../bq-schemas/datalake_cdm.good_events.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "collector_tstamp"
    expiration_ms            = "10368000"
    require_partition_filter = "true"
  }
}

resource "google_bigquery_table" "datalake_cdm_bad_events" {
  project    = var.project_id
  table_id   = "bad_events"
  dataset_id = google_bigquery_dataset.datalake_cdm.dataset_id
  schema     = file("../bq-schemas/datalake_cdm.bad_events.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "failure_tstamp"
    expiration_ms            = "10368000"
    require_partition_filter = "true"
  }
}

resource "google_bigquery_table" "datalake_bdm_intermediate_edges" {
  project    = var.project_id
  table_id   = "edges"
  dataset_id = google_bigquery_dataset.datalake_bdm_intermediate.dataset_id
  schema     = file("../bq-schemas/datalake_bdm_intermediate.edges.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "collector_tstamp"
    expiration_ms            = "10368000"
    require_partition_filter = "true"
  }
}

resource "google_bigquery_table" "datalake_bdm_akagt_daily" {
  project    = var.project_id
  table_id   = "akagt_daily"
  dataset_id = google_bigquery_dataset.datalake_bdm.dataset_id
  schema     = file("../bq-schemas/datalake_bdm.akagt_daily.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "dt"
    expiration_ms            = "864000"
    require_partition_filter = "true"
  }
}

resource "google_bigquery_table" "newsid_prod_good_events" {
  project    = var.project_id
  table_id   = "good_events"
  dataset_id = google_bigquery_dataset.newsid_prod.dataset_id
  schema     = file("../bq-schemas/newsid_prod.good_events.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "collector_tstamp"
    require_partition_filter = "true"
  }
}

resource "google_bigquery_table" "newsid_prod_bad_events" {
  project    = var.project_id
  table_id   = "bad_events"
  dataset_id = google_bigquery_dataset.newsid_prod.dataset_id
  schema     = file("../bq-schemas/newsid_prod.bad_events.json")

  time_partitioning {
    type                     = "DAY"
    field                    = "failure_tstamp"
  }
}

resource "google_bigquery_table" "newsid_prod_bad_events_v1" {
  project    = var.project_id
  table_id   = "bad_events_v1"
  dataset_id = google_bigquery_dataset.newsid_prod.dataset_id
  schema     = file("../bq-schemas/newsid_prod.bad_events_v1.json")

  time_partitioning {
    type = "DAY"
  }
}

resource "google_bigquery_table" "datalake_bdm_intermediate_pre_cluster" {
  project    = var.project_id
  table_id   = "pre_cluster"
  dataset_id = google_bigquery_dataset.datalake_bdm_intermediate.dataset_id
  schema     = file("../bq-schemas/datalake_bdm_intermediate.pre_cluster.json")
}

resource "google_bigquery_table" "datalake_bdm_intermediate_cluster" {
  project    = var.project_id
  table_id   = "cluster"
  dataset_id = google_bigquery_dataset.datalake_bdm_intermediate.dataset_id
  schema     = file("../bq-schemas/datalake_bdm_intermediate.cluster.json")
}

resource "google_bigquery_table" "datalake_bdm_intermediate_good_events_edges" {
  project    = var.project_id
  table_id   = "good_events_edges"
  dataset_id = google_bigquery_dataset.datalake_bdm_intermediate.dataset_id
  schema     = file("../bq-schemas/datalake_bdm_intermediate.good_events_edges.json")
}

resource "google_bigquery_table" "datalake_bdm_intermediate_cluster_staging" {
  project    = var.project_id
  table_id   = "cluster_staging"
  dataset_id = google_bigquery_dataset.datalake_bdm_intermediate.dataset_id
  schema     = file("../bq-schemas/datalake_bdm_intermediate.cluster_staging.json")
}

resource "google_bigquery_table" "datalake_bdm_akagt" {
  project    = var.project_id
  table_id   = "akagt"
  dataset_id = google_bigquery_dataset.datalake_bdm.dataset_id
  schema     = file("../bq-schemas/datalake_bdm.akagt.json")
}

resource "google_bigquery_table" "datalake_bdm_akagt_audit" {
  project    = var.project_id
  table_id   = "akagt_audit"
  dataset_id = google_bigquery_dataset.datalake_bdm.dataset_id
  schema     = file("../bq-schemas/datalake_bdm.akagt_audit.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_cluster" {
  project    = var.project_id
  table_id   = "sp_cluster"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_cluster.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_edges" {
  project    = var.project_id
  table_id   = "sp_edges"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_edges.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_full_graph" {
  project    = var.project_id
  table_id   = "sp_full_graph"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_full_graph.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_original_edges" {
  project    = var.project_id
  table_id   = "sp_original_edges"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_original_edges.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_pre_cluster" {
  project    = var.project_id
  table_id   = "sp_pre_cluster"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_pre_cluster.json")
}

resource "google_bigquery_table" "datalake_scratchpad_sp_vertex_ids" {
  project    = var.project_id
  table_id   = "sp_vertex_ids"
  dataset_id = google_bigquery_dataset.datalake_scratchpad.dataset_id
  schema     = file("../bq-schemas/datalake_scratchpad.sp_vertex_ids.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_crawler_useragents" {
  project    = var.project_id
  table_id   = "crawler_useragents"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.crawler_useragents.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_domain_whitelist" {
  project    = var.project_id
  table_id   = "domain_whitelist"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.domain_whitelist.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_ip_org_blacklist" {
  project    = var.project_id
  table_id   = "ip_org_blacklist"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.ip_org_blacklist.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_manual_useragent" {
  project    = var.project_id
  table_id   = "manual_useragent"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.manual_useragent.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_piwik_useragents" {
  project    = var.project_id
  table_id   = "piwik_useragents"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.piwik_useragents.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_udger_crawler_list" {
  project    = var.project_id
  table_id   = "udger_crawler_list"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.udger_crawler_list.json")
}

resource "google_bigquery_table" "newsid_pixel_seed_udger_datacenters" {
  project    = var.project_id
  table_id   = "udger_datacenters"
  dataset_id = google_bigquery_dataset.newsid_pixel_seed.dataset_id
  schema     = file("../bq-schemas/newsid_pixel_seed.udger_datacenters.json")
}

resource "google_bigquery_table" "datalake_seed_data_crawler_useragents" {
  project    = var.project_id
  table_id   = "crawler_useragents"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.crawler_useragents.json")
}

resource "google_bigquery_table" "datalake_seed_data_domain_whitelist" {
  project    = var.project_id
  table_id   = "domain_whitelist"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.domain_whitelist.json")
}

resource "google_bigquery_table" "datalake_seed_data_ip_org_blacklist" {
  project    = var.project_id
  table_id   = "ip_org_blacklist"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.ip_org_blacklist.json")
}

resource "google_bigquery_table" "datalake_seed_data_ip_org_whitelist" {
  project    = var.project_id
  table_id   = "ip_org_whitelist"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.ip_org_whitelist.json")
}

resource "google_bigquery_table" "datalake_seed_data_manual_useragent" {
  project    = var.project_id
  table_id   = "manual_useragent"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.manual_useragent.json")
}

resource "google_bigquery_table" "datalake_seed_data_piwik_useragents" {
  project    = var.project_id
  table_id   = "piwik_useragents"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.piwik_useragents.json")
}

resource "google_bigquery_table" "datalake_seed_data_udger_crawler_list" {
  project    = var.project_id
  table_id   = "udger_crawler_list"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.udger_crawler_list.json")
}

resource "google_bigquery_table" "datalake_seed_data_udger_datacenters" {
  project    = var.project_id
  table_id   = "udger_datacenters"
  dataset_id = google_bigquery_dataset.datalake_seed_data.dataset_id
  schema     = file("../bq-schemas/datalake_seed_data.udger_datacenters.json")
}

resource "google_bigquery_table" "newsid_prod_bad_events_v1_error_records" {
  project    = var.project_id
  table_id   = "bad_events_v1_error_records"
  dataset_id = google_bigquery_dataset.newsid_prod.dataset_id
  schema     = file("../bq-schemas/newsid_prod.bad_events_v1_error_records.json")
}
