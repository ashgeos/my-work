# Big Query Eviction
\
Major billing cost from google comes with data residing in bigquery, so inorder to avoid heavy charges we extract the bigquery tabes in zipped format to google cloud storage bucket which compared to bigquery has lesser cost and later delete the tables from bigquey. These backed up tables can be restored to bigquery on demand as long as the backups are availabe in google storage bucket.

The table extraction job is carried out by biq query extraction job. The job extracts the table from bigquery and dumps it in GCS bucket specified.

There are multiple scenarios that needs to be handled in the entire eviction process, for each scenario a corresponding policy written in python is available. it will be explained later during this readme.

![Eviction Diagram][d]

[d]: diagrams/eviction.png "eviction Diagram"

## Requirements
\
To execute this python script there are a couple of files that are required. Below directory structure needs to be in place.

![Alt text](diagrams/folder_structure.png?raw=false "folder_structure Diagram")

## Main eviction script
\
If you want to run the eviction process, you need to run the eviction.py script, provided the dataset, tables and policy are specified in bq-eviction-policy-configmap located in GCP.

eg yaml file
```
newsiq_dfp:
    dj_bids_: delete_no_eviction:5
    dj_imps_: delete_no_eviction:5
    dj_reg_imps_: delete_no_eviction:5
    dj_clicks_: delete_no_eviction:5
    dj_reg_clicks_: delete_no_eviction:5
    dj_codeServes_: delete_no_eviction:5
    dj_reg_codeServes_: delete_no_eviction:5
    dj_requests_: delete_no_eviction:5
    dj_reg_requests_: delete_no_eviction:5
    nyp_bids_: delete_no_eviction:5
    nyp_imps_: delete_no_eviction:5
    nyp_reg_imps_: delete_no_eviction:5
    nyp_clicks_: delete_no_eviction:5
    nyp_reg_clicks_: delete_no_eviction:5
    nyp_codeServes_: delete_no_eviction:5
    nyp_reg_codeServes_: delete_no_eviction:5
    nyp_requests_: delete_no_eviction:5
    nyp_reg_requests_: delete_no_eviction:5
    realtor_bids_: delete_no_eviction:5
    realtor_imps_: delete_no_eviction:5
    realtor_reg_imps_: delete_no_eviction:5
    realtor_clicks_: delete_no_eviction:5
    realtor_reg_clicks_: delete_no_eviction:5
    realtor_codeServes_: delete_no_eviction:5
    realtor_reg_codeServes_: delete_no_eviction:5
    realtor_requests_: delete_no_eviction:5
    realtor_reg_requests_: delete_no_eviction:5
    dj_joined_: delete_no_eviction:4
    dj_reg_joined_: delete_no_eviction:4
    realtor_joined_: delete_no_eviction:4
    realtor_reg_joined_: delete_no_eviction:4
    nyp_joined_: delete_no_eviction:4
    nyp_reg_joined_: delete_no_eviction:4
    backfill_with_segments_: delete_no_eviction:2
    non_backfill_with_segments_: delete_no_eviction:2
newsiq_ad_value:
    backfill_: delete_no_eviction:90
    non_backfill_: delete_no_eviction:90
newsiq_prebid:
    prebid_analytics_: delete_no_eviction:7
    prebid_temp_staging_: delete_no_eviction:5
    prebid_staging_: delete_no_eviction:5
newsiq_pixel:
    akagt_: delete_no_eviction:5
    article_: delete_no_eviction:2
    relisting_: delete_no_eviction:2
    research_: delete_no_eviction:2
    events_: delete_no_eviction:1
    events_joined_: delete_and_evict:90
newsiq_krux:
    audience_segment_map_: delete_no_eviction:7
    audience_segments_: delete_no_eviction:7
    dissent_data_: delete_no_eviction:7
    partner_user_match_: delete_no_eviction:7
    segment_map_clean_: delete_no_eviction:7
newsiq_pixel_features:
    nlp_time_features_: delete_no_eviction:1
    nlp_time_metrics_: delete_no_eviction:1
    nlp_time_metrics_window_12w_: delete_no_eviction:1
    nlp_time_metrics_window_1d_: delete_no_eviction:1
    nlp_time_metrics_window_1w_: delete_no_eviction:1
    nlp_time_metrics_window_2w_: delete_no_eviction:1
    nlp_time_metrics_window_4w_: delete_no_eviction:1
    nlp_time_metrics_window_8w_: delete_no_eviction:1
    re_features_: delete_no_eviction:2
newsiq_id_mappings:
    news_to_domain_: delete_no_eviction:90
    news_to_user_: delete_no_eviction:90
    news_to_aaid_: delete_no_eviction:90
    news_to_idfa_: delete_no_eviction:90
    news_to_krux_pum_: delete_no_eviction:2
    news_to_krux_akagt_: delete_no_eviction:2
newsiq_pixel_segments:
    farsi_language_segments_: delete_no_eviction:1
    re_segments_: delete_no_eviction:3
    religious_segments_: delete_no_eviction:1
    spanish_language_segments_: delete_no_eviction:1
newsiq_exports:
    consent_data_: delete_no_eviction:1
    nlp_attrs_fpid_02_: delete_no_eviction:1
    nlp_attrs_fpid_04_: delete_no_eviction:1
    nlp_attrs_fpid_06_: delete_no_eviction:1
    nlp_attrs_fpid_08_: delete_no_eviction:1
    nlp_attrs_fpid_10_: delete_no_eviction:1
    nlp_attrs_fpid_12_: delete_no_eviction:1
    nlp_attrs_fpid_pieces_: delete_no_eviction:1
    nlp_attrs_tpid_: delete_no_eviction:1
    segments_fpid_: delete_no_eviction:1
    segments_tpid_: delete_no_eviction:1
    test_aid_: delete_no_eviction:1
    test_did_: delete_no_eviction:1
    test_did_w_uid_: delete_no_eviction:1
    test_did_wo_uid_: delete_no_eviction:1
    test_ifa_: delete_no_eviction:1
    test_kid_: delete_no_eviction:1
    test_uid_: delete_no_eviction:1
live_ramp:
    IDGraph_AAID: partitioned_delete_no_eviction:1
    IDGraph_Cookie: partitioned_delete_no_eviction:1
    IDGraph_IDFA: partitioned_delete_no_eviction:1
```

### How it works

1. The bq-eviction-policy-configmap CONFIGMAP in GCP is volume mounted as a part of the deployment which mounts eviction.yml under the eviction folder, the script reads the eviction.yml to load the dataset, tables and the policy that needs to be applied on the table.
2. For each table the respective policy is applied, and this repeated for the n number of tables specified in eviction.yml file.

The policy python script contains the logic to perform what is needed against each table.

##### Usage
\
```python eviction.py```
## Policies
\
As mentioned earlier, there are multiple scenarios when it comes to eviction, they are explained further in detail.

##### 1. `__init__.py`
\
This script contains all the core functions that are utilized by other policies.
1. `get_gcp_project` : Obtains the GCP project name from the environment or defaults
    to DEV otherwise.
2. `get_bq_client` : Obtains the BigQuery client, looks for credentials from the
    environment or defaults to a local file otherwise.
3. `get_gcs_client` : Obtains the GCS client, looks for credentials from the environment
    or defaults to a local file otherwise.
4. `table_name_matches` : Given a table reference and a table_name, this function tries to
    define if it matches using some criteria.
5. `get_gcs_bucket` : Obtains the GCS bucket name, looks for environment from the
    environment variable.
6. `extract_to_gcs` : Extracts the table schema from biqquery to GCS bucket and triggers a biq query extraction job to extract the table from bigquery to GCS bucket.
7. `delete_table` : This method is used across all policies when deleting a table is
    required so that it can be done consistently.
8. `delete_table_with_retention` : This method is used only on delete_no_eviction policy where a data retention policy number is specified. eg news_to_domain_: delete_no_eviction:90 . Here as per the policy the script needs to retain 90 days of table data in big query and delete the rest.
9. `evict_and_delete_table_with_retention` : This method is used only on delete_and_evict policy where a data retention policy number is specified. eg news_to_domain_: delete_and_evict:90 . Here as per the policy the script needs to retain 90 days of table data in big query and backups the rest to GCS and later deletes it from big query.
10. `evict_only_no_delete_table_with_retention` : This method is used only on eviction_no_delete policy where a data retention policy is set to daily only partitioned tables. eg ecpm_lookup: eviction_no_delete:daily . Here as per the policy the script will backup the partitioned tables daily to GCS. 
11. `random_string` : Just generates a random
    string of fixed length to be used later when generating seed data
    for temporary tables created during the Unit Tests.
12. `log_msg` : Prints a log message to the stderr

##### 2. `delete_and_evict`
\
This function contains 2 conditions for normal tables.
1. Evicts and Deletes all the tables in the dataset passed as parameter when the table names match the given table name as per the `table_name_matches` function, by calling the `extract_to_gcs` and `delete_table` function inside `__init__.py`.
2. In case a retention policy is set, the function gets a list of tables by calling `evict_and_delete_table_with_retention` that needs to be deleted and then Evicts and deletes all the tables found for that dataset by calling the `extract_to_gcs` and `delete_table` function inside `__init__.py`.

##### 3. `delete_no_eviction`
\
The function consists of 2 conditons only for normal tables.
1. Deletes all the tables in the dataset passed as parameter when the table names match the given table name as per the `table_name_matches` function, by calling the `delete_table` function inside `__init__.py`
2. In case a retention policy is set for a table, the function gets a list of tables by calling `delete_table_with_retention` that needs to be deleted and then deletes all the tables found for that dataset by calling the `delete_table` function inside `__init__.py`.

##### 4. `keep_everything`
\
This basically does nothing, it will just list all the tables inside bq-eviction-policy-configmap in GCP.

##### 5. `keep_latest_only`
\
Deletes all the tables from the passed dataset as parameter when they match the given name as per the table_name_matches function, by calling the `delete_table` function inside `__init__.py` except for the latest table. The latest table is defined based on the date found at the end of the table name.

##### 6. `restore_from_gcs`
\
Tries to recover a table from Google Storage.

##### 7. `partitioned_delete_no_eviction`
\
This function contains the logic for data retention policy(delete_table_with_retention function) only for Partitioned tables.
In case of delete_table_with_retention function, based on the retention policy(Number of days to keep the table data) the function calls a shell script find_tables_for_deletion_with_retention.sh to make it happen. 

##### 8. `eviction_no_delete`
\
This function contains the logic for data retention policy(evict_only_no_delete_table_with_retention function) only for Partitioned tables for daily backup to GCS.
In case of evict_only_no_delete_table_with_retention function, the function calls a shell script find_tables_for_deletion_with_retention.sh to make it happen. 
##### 9. `bq_table_to_gcs.sh`
\
This script is getting triggered from `extract_to_gcs` function inside `__init__.py` script. execution of the script requires a couple of parameters mentioned in usage section.
Basically this script triggers a apache beam dataflow job that will extract the tables from bigquery and dump it to the storage bucket specified and polls for the job to complete if polling is enabled for a maximum of 2 hours and 15 minutes.
###### Usage 
```sh bq_table_to_gcs.sh <-p or -np> <PROJECT_ID> <GCS_BUCKET_NAME> <TABLE NAME> <DATASET NAME> <PYINSTALL (-y or -n )> <PYPATH> <WORKER COUNT> <MAX WORKER COUNT>```
###### Options

-p or -np &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: You can enable polling of the dataflow job by using -p and disbale polling using -np

PROJECT_ID &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The GCP project where BQ table extraction is required.

GCS_BUCKET_NAME &nbsp;&nbsp;&nbsp;&nbsp;: The GCS bucket where you need the extracted bigquery table to be dumped.

TABLE NAME &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The bigquery table name to be extracted.

DATASET NAME &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The dataset name the table is a part of.

PYINSTALL &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: -y if you need to install python 3.6 as a part of this job. -n if you want to skip it.

PYPATH &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: A valid python2 path needs to be specified.

WORKER COUNT &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The minimum worker count the data flow job needs to start with.

MAX WORKER COUNT &nbsp; : The maximum number of workers the dataflow job can scale upto.

###### How it works
This script mainly calls `bq_table_to_gcs.py` script with its parameters.
1. An apache beam dataflow job is triggered and the job id is captured.
``` python bq_table_to_gcs.py --bql "select * from \`${PROJECT_ID}.${DATASET_NAME}.${table}\`" \
--output gs://${BUCKET_NAME}/${DATASET_NAME}/${table}/ \
--project ${PROJECT_ID} \
--job_name ${jobName} \
--staging_location gs://${BUCKET_NAME}/staging_location \
--temp_location gs://${BUCKET_NAME}/temp_location \
--region us-east1 \
--num_workers ${WORKERCOUNT} \
--max_num_workers ${MAXWORKERCOUNT} \
--runner DataflowRunner \
--save_main_session True \
--requirements_file ${policylocation}/requirements.txt ```
2. The script keeps polling for the job status untill it reaches these states Cancelled, Failed, Done or  Cancelling,  by using the below command(gsutil needs to installed on the server as a requirement for this cmmand to run)
```gcloud --project=${PROJECT_ID} dataflow jobs list --filter="id=${job_id}" --format="get(state)" --region="us-east1"```
3. If the job runs for more than 2 hours and 15 minutes, then the polling is stopped and the job status is updated accordingly.
##### 10. `bq_table_to_gcs.py`
\
Beam code for extracting data from BQ to NDJSON GZip, the script constructs a dataflow pipeline, developed using python SDK.
The pipeline consists of mainly 3 parts.
1. Input: QueryTable : which queries bigquery table data.
2. To JSON : Converts queried data into simplejson.
3. Dump as NDJSON GZip : Dumps the NDJSON as GZIP into the GCS bucket.

``` 
    p = beam.Pipeline(options=options)
    p | 'Input: QueryTable' >> beam.io.Read(beam.io.BigQuerySource(
        query=known_args.bql,
        use_standard_sql=True)) \
    | "To JSON" >> beam.Map(lambda row: simplejson.dumps(row)) \
    | 'Dump as NDJSON GZip' >> io.textio.WriteToText(
        compression_type=CompressionTypes.AUTO,
        file_path_prefix=known_args.ouput,
        file_name_suffix=".json.gz")
```
##### 11. `find_tables_for_deletion_with_retention.sh`
\
The sole purpose of this bash script is to enforce data retention policy for a set a tables defined. The script gets the list of tables based on retention policy. In case of partitioned tables only the script deletes the tables based on the policy set, for all the other cases the script returns a list of tables to be deleted.

###### Usage 
```bash find_tables_for_deletion_with_retention.sh  <dry_run> <project> <downstream_buffer> <dataset_id> <table_id> <retention_period> <statuslocation>```
###### Options

dry_run &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: By setting dry_run "true" the script will simulate what all tables will be deleted, by setting dry_run &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"false" the script will delete the tables.

project &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The GCP project where BQ table deletion is required.

downstream_buffer &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The number of days to keep the tables even though the table needs to be deleted as per the &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;policy(due to downstream_buffer)

dataset_id &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The dataset name the table is a part of.

table_id &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The bigquery table name to be deleted. eg fromat is "news_to_domain_"

retention_period &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: The number of days of tables to keep in big query, all the tables older than the retention_period is &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;deleted.

statuslocation &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: A valid log path where the deletion status of the tables is stored.

###### What the script does?

The script mainly handles the below scenarios,
1. Gets the list of applicable normal tables based on the retention period specified. 
2. Deletes the applicable time_partitioned tables based on the retention period specified.
4. Calculates the downstream_buffer based policy for tables under "newsiq_dfp" "newsiq_pixel" "newsiq_prebid" "newsiq_ad_value", eg :  if a table is meant to be deleted as per the policy but is under the datasets defined under downstream buffer, those tables Last Modified Date is checked and if it is modified in past "N" days, (N=downstream buffer days) those tables are skipped under the assumption that some new data has come in to the tabels which may not be ingested to the joined tables.
