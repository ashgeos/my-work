#!/bin/bash
# This script is meant to create all the nesseary datasets and tables for a new snowplow infrastructure,
# please make sure no datasets are present in BQ project before you run this script.
# Please update bq-create-newsid-tables-list.txt file if more tables needs to be created.

# The Target GCP BQ project where tables are to be created, please update this value before you proceed.
project="nchq-newsuk-nonprod-newsid"

read -p "The datasets and tables will be created under ${project} project. Do you wich to proceed? [y/n]: " proceed

if [[ "${proceed}" == "N" || "${proceed}" == "n" ]]; then
    exit 0
elif  [[ "${proceed}" == "Y" || "${proceed}" == "y" ]]; then
    :
else
    echo "Invalid Input"
    exit 0
fi

# Download schema files from  newscorp-newsid-dev BQ project
mkdir -p ./bq-schemas
echo "Downloading table schemas....."
while read line;
do
    table=`echo $line | awk -F "." '{print $2}'`
    dataset=`echo $line | awk -F ":" '{print $2}' | awk -F "." '{print $1}'`
    bq show --schema --format=prettyjson $line > ./bq-schemas/${dataset}.${table}.json
done < ./newsid-download-table-schema-list.txt
exit 0
# Create datasets
declare -a dataset_array=("datalake_bdm" "datalake_cdm" "datalake_bdm_intermediate" "datalake_scratchpad" "newsid_pixel_seed" "datalake_seed_data" "${new_snowplow_dataset}")
for datasetVal in ${dataset_array[@]}; do
    bq mk --location "EU"  --description "Dataset used by populate_datalake_v2 Airflow DAG for snowplow" --dataset "${project}:${datasetVal}"
    sleep 5
done


while read line;
do 
    dataset=`echo $line | awk -F "." '{print $1}'`
    table=`echo $line | awk -F "." '{print $2}'`
    if [[ "${dataset}" == "datalake_scratchpad" || "${dataset}" == "datalake_seed_data" || "${dataset}" == "newsid_pixel_seed" ]] ; then
        bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON ${project}:${dataset}.${table} "gs://newsid-snowplow-prerequisite-tables-with-data/${dataset}/${table}/*.json" 
        echo "Table '${project}:${dataset}.${table}' successfully created and loaded with data"
    else
        bq mk --table ${project}:${dataset}.${table} ./bq-schemas/${dataset}.${table}.json
    fi

done < ./bq-create-newsid-tables-list.txt

# Create partitioned tables
# good_events
bq mk -t --schema ./bq-schemas/newsid_prod.good_events.json --time_partitioning_type DAY  --time_partitioning_field collector_tstamp \
--require_partition_filter=True ${project}:newsid_prod.good_events

# bad_events
bq mk -t --schema ./bq-schemas/newsid_prod.bad_events.json --time_partitioning_type DAY  --time_partitioning_field failure_tstamp \
--require_partition_filter=False ${project}:newsid_prod.bad_events

# bad_events_v1
bq mk -t --schema ./bq-schemas/newsid_prod.bad_events_v1.json --time_partitioning_type DAY  \
--require_partition_filter=False ${project}:newsid_prod.bad_events_v1

# datalake_bdm_intermediate.edges
bq mk -t --schema ./bq-schemas/datalake_bdm_intermediate.edges.json --time_partitioning_type DAY  --time_partitioning_field collector_tstamp \
--time_partitioning_expiration 10368000  --require_partition_filter=True ${project}:datalake_bdm_intermediate.edges

# datalake_bdm.akagt_daily
bq mk -t --schema ./bq-schemas/datalake_bdm.akagt_daily.json --time_partitioning_type DAY  --time_partitioning_field dt \
--time_partitioning_expiration 864000  --require_partition_filter=True ${project}:datalake_bdm.akagt_daily

# datalake_cdm.good_events
bq mk -t --schema ./bq-schemas/datalake_cdm.good_events.json --time_partitioning_type DAY  --time_partitioning_field collector_tstamp \
--time_partitioning_expiration 10368000 --require_partition_filter=True ${project}:datalake_cdm.good_events

# datalake_cdm.bad_events
bq mk -t --schema ./bq-schemas/datalake_cdm.bad_events.json --time_partitioning_type DAY  --time_partitioning_field failure_tstamp \
--time_partitioning_expiration 10368000 --require_partition_filter=True ${project}:datalake_cdm.bad_events

# Delete bq-schemas folder
rm -rf ./bq-schemas