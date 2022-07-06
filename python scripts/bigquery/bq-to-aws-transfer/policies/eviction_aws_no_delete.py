from sys import stderr
from . import extract_to_gcs
from . import get_bq_client
from . import get_gcp_project
from . import table_name_matches
from . import log_msg
import subprocess
import time
from os import getenv
from google.api_core.exceptions import NotFound

def apply(dataset, table_name, retention_period, dry_run = False):
    """
    Evicts all the tables in the dataset passed as parameter with the retention period or for single tables.
    NOTE : This policy can be applied to normal tables as well as "day" or "_PARTITIONTIME" partitioned tables.
    Nomal tables just needs the table name but to distinguish a day partitioned table "daily" should be the rentention policy.
    # Eg adx_dealid: eviction_no_delete:daily
    """

    retention_period = retention_period
    eviction_policy = "eviction_aws_no_delete"
    # Processes the dataset tables looking for matches, this is for a single normal table or a single day partitioned table.
    if retention_period == "false":
        client = get_bq_client()
        dataset_id = "{}.{}".format(get_gcp_project(), dataset)
        tables = client.list_tables(dataset_id, max_results=100000)
        awsStoragelocation = getenv('NEWSIQ_AWS_STORAGE_LOCATION', 's3://bq-evictions-for-aws-transfer-prod')
        try:
            for table in tables:
                if table_name_matches(table, table_name):
                    if dry_run == "True":
                        log_msg("Table {} is marked for eviction as per dry_run".format(
                                table.table_id
                            )
                        )
                    elif dry_run == "False":
                        # Evicts the table from BigQuery to GCS
                        extract_to_gcs(dataset, table.table_id, eviction_policy)
                        # Transfers the table from GCS to AWS
                        with open('/bq-to-aws-transfer/logs/destination_uri.txt', 'r') as file:
                            gcsEvictedFolder = file.read()
                        with open('/bq-to-aws-transfer/logs/aws_transfer_folder.txt', 'r') as file:
                            awsTransferFolder = file.read()
                        gcs_to_awsS3_run = '''bash gsutil -m rsync -r {gcsEvictedFolder} {awsStoragelocation}{awsTransferFolder} '''
                        gcs_to_awsS3_status = subprocess.check_output(gcs_to_awsS3_run.format(
                                                    gcsEvictedFolder = gcsEvictedFolder,
                                                    awsStoragelocation = awsStoragelocation,
                                                    awsTransferFolder = awsTransferFolder),
                                                    shell=True, 
                                                    universal_newlines=True)
                        print(gcs_to_awsS3_status)
                    else:
                        print "dry_run vlaue missing"
        except NotFound:
            log_msg(
                "Table {} not found when searching for it for eviction.".format(
                    table.table_id
                )
            )
    else:
        log_msg(
                "Retention period True is not handled in this case"
        )