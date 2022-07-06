import json
import string
import random
import inspect
import subprocess
import os
import re
from os import getenv
from re import search
from sys import stderr
from datetime import datetime
from google.cloud import bigquery
from google.cloud import storage
from google.cloud import exceptions
from google.oauth2.service_account import Credentials
from google.api_core.exceptions import NotFound

# A global variable defined for eviction of already exixtant backups in GCS.
oldBackupExists = ""

def get_gcp_project():
    """
    Obtains the GCP project name from the environment or defaults
    to DEV otherwise.
    """
    return getenv('NEWSIQ_GCP_PROJECT', 'ashish-test')

def get_bq_client():
    """
    Obtains the BigQuery client, looks for credentials from the
    environment or defaults to a local file otherwise.
    """
    gcp_key_path = getenv(
        'GOOGLE_APPLICATION_CREDENTIALS',
        '/secrets/gcp/credentials.json'
    )
    auth = Credentials.from_service_account_file(gcp_key_path)
    return bigquery.Client(project=get_gcp_project(), credentials=auth)

def get_gcs_client():
    """
    Obtains the GCS client, looks for credentials from the environment
    or defaults to a local file otherwise.
    """
    gcp_key_path = getenv(
        'GOOGLE_APPLICATION_CREDENTIALS',
        '/secrets/gcp/credentials.json'
    )
    auth = Credentials.from_service_account_file(gcp_key_path)
    return storage.Client(project=get_gcp_project(), credentials=auth)

def table_name_matches(table, table_name):
    """
    Given a table reference and a table_name, this function tries to
    define if it matches using this criteria:
        - It discards VIEWS or other table types from BigQuery.
        - The table reference table_id attribute and the table name
          given are the same.
        - The table reference table_id attribute contains a date in the
          YYYYMMDD format at the end, and once we strip that date and
          proceed to compare with the table name given we obtain a
          match.
    """
    # We only work with TABLEs
    if table.table_type == 'TABLE':
        # exact matches return True immediatelly
        if table.table_id == table_name:
            log_msg("{}.{}.{} matches {}".format(
                    get_gcp_project(),
                    table.dataset_id,
                    table.table_id,
                    table_name
                )
            )
            return True
        else:
            # process date sharded tables
            if search('_[0-9]{8}$', table.table_id):
                last_separator = table.table_id.rfind('_')
                t_name = table.table_id[:last_separator]
                if t_name == table_name:
                    log_msg("{}.{}.{} matches {}".format(
                            get_gcp_project(),
                            table.dataset_id,
                            table.table_id,
                            table_name
                        )
                    )
                    return True
    return False

def get_gcs_bucket():
    environ = getenv('NEWSIQ_ENV', 'dev')
    return "bq-evictions-for-aws-transfer-{}".format(environ)

def backup_existent_gcs(dataset, table_id, isNormal=True, isDayPartitioned=False):
    global oldBackupExists
    gcs_client = get_gcs_client()
    bucket = gcs_client.get_bucket(get_gcs_bucket())
    if isNormal:
        table_name = re.sub(r'\d+', '', table_id).rstrip('_')
        for old_backup in bucket.list_blobs(prefix="{}/{}/{}/{}".format(
        dataset,
        table_name,
        table_id,
        table_id
        )):
            if old_backup.name.endswith('.json.gz'):
                log_msg("Backup {} already exists..!!".format(
                    old_backup.name
                    )
                )
                oldBackupExists = "True"
                break
    elif isDayPartitioned:
        table_day_id, table_day_partition = table_id.split('$')
        for old_backup in bucket.list_blobs(prefix="{}/{}/{}".format(
        dataset,
        table_day_id,
        table_day_partition
        )): 
            if old_backup.name.endswith('.json.gz'):
                log_msg("Backup {} already exists..!!".format(
                    old_backup.name
                    )
                )
                oldBackupExists = "True"
                break
    else:
        log_msg("Unable to figure out the table type..!!")

def extract_to_gcs(dataset_id, table_id, eviction_policy, backup=True, isNormal=True, isDayPartitioned=False):
    """
    Extracts the contents from the table specified on the parameters
    to a bucket in GCS.
    """
    global oldBackupExists
    # Proceeds with the extract
    client = get_bq_client()
    gcs_client = get_gcs_client()
    # Obtains the dataset and table references
    dataset_ref = client.dataset(dataset_id, project=get_gcp_project())
    table_ref = dataset_ref.table(table_id)
    time_delta = datetime.today().strftime('%Y%m%d%H%M%S')
    # backups any already existent backups for this table
    # this could happen if for example we are processing a
    # table that was restored from GCS from its backup and
    # now we are evicting that same table again.
    if backup:
        log_msg("Checking if backup already exists..!!")
        backup_existent_gcs(dataset_id, table_id, isNormal, isDayPartitioned)
    # Extracts the Schema
    if oldBackupExists == "True":
        log_msg("Will *not be* backing up table {} as backup already exists...!!".format(
                table_id
                )
        )    
        #Resetting the global variable for next iteration
        oldBackupExists = "False"
        return True
    elif oldBackupExists == "False":
        log_msg("Backup *does not* exist for table {} ..!!".format(
                table_id
                )
        )       
    table = client.get_table(table_ref)
    try:
        with open("/tmp/schema-{}.txt".format(table_id), 'w') as schema_file:
            schema_file.write(str(table.to_api_repr()))
    except IOError:
        log_msg("Cannot open the temporary table schema file for writing.")
        return False
    try:
        bucket = gcs_client.get_bucket(get_gcs_bucket())
    except NotFound:
        log_msg("Could not open the storage bucket.")
        return False
    if isNormal:
        table_name = re.sub(r'\d+', '', table_id).rstrip('_')
        blob = storage.Blob("{}/{}/{}/schema.txt".format(
                dataset_id,
                table_name,
                table_id,
                ),
                bucket
        )
        gcs_evicted_folder = ("gs://{}/{}/{}/{}/").format(
                get_gcs_bucket(),
                dataset_id,
                table_name,
                table_id)
        gcs_evicted_schema = ("gs://{}/{}/{}/{}/schema.txt").format(
                get_gcs_bucket(),
                dataset_id,
                table_name,
                table_id)
    elif isDayPartitioned:
        table_day_id, table_day_partition = table_id.split('$')
        blob = storage.Blob("{}/{}/{}/schema.txt".format(
                dataset_id,
                table_day_id,
                table_day_partition
                ),
                bucket
        )
        gcs_evicted_folder = ("gs://{}/{}/{}/{}/").format(
                get_gcs_bucket(),
                dataset_id,
                table_day_id,
                table_day_partition)
        gcs_evicted_schema = ("gs://{}/{}/{}/{}/schema.txt").format(
            get_gcs_bucket(),
            dataset_id,
            table_day_id,
            table_day_partition)
    else:
        blob = storage.Blob("{}/{}/{}/schema.txt".format(
                dataset_id,
                table_id,
                time_delta
                ),
                bucket
        )
        gcs_evicted_folder = ("gs://{}/{}/{}/{}/").format(
                get_gcs_bucket(),
                dataset_id,
                table_id,
                time_delta)
        gcs_evicted_schema = ("gs://{}/{}/{}/{}/schema.txt").format(
            get_gcs_bucket(),
            dataset_id,
            table_id,
            time_delta)
    try:
        with open("/tmp/schema-{}.txt".format(table_id)) as blob_file:
            blob.upload_from_file(blob_file)
            log_msg("Created schema file {}".format(blob.name))
    except IOError:
        log_msg("Error opening the schema file for reading.")
        return False
    except exceptions.GoogleCloudError:
        log_msg("Error uploading the schema file to GCS.")
        return False
    # Constructs the object address
    # The wildcard will allow to create multiple files 1GB each to
    # a maximum of 10TB a day in total for all extracts project wide.
    if isNormal:
        table_name = re.sub(r'\d+', '', table_id).rstrip('_')
        destination_uri = "gs://{}/{}/{}/{}/{}-*.json.gz".format(
                get_gcs_bucket(),
                dataset_id,
                table_name,
                table_id,
                table_id
        )
    elif isDayPartitioned:
        table_day_id, table_day_partition = table_id.split('$')
        destination_uri = "gs://{}/{}/{}/{}/{}-*.json.gz".format(
                get_gcs_bucket(),
                dataset_id,
                table_day_id,
                table_day_partition,
                table_day_partition
        )
    else:
        destination_uri = "gs://{}/{}/{}/{}/{}-*.json.gz".format(
                get_gcs_bucket(),
                dataset_id,
                table_id,
                time_delta,
                table_id
        )
    # Configures the extract job
    dst_fmt = bigquery.job.DestinationFormat.NEWLINE_DELIMITED_JSON
    job_config = bigquery.job.ExtractJobConfig()
    job_config.compression = bigquery.job.Compression.GZIP
    job_config.destination_format = dst_fmt
    job_config.print_header = True
    # Creates the extract job
    extract_job = client.extract_table(
        table_ref,
        destination_uri,
        # Location must match that of the source table.
        location="US",
        job_config=job_config
    )  # API request
    # Executes the job and waits for it to complete.
    # It might take long for large extracts.
    try:
        extract_job.result()
    except:
        # Feedback
        log_msg(
            "Failed to export {}:{}.{} to {}, reason: {}".format(
                get_gcp_project(),
                dataset_id,
                table_id,
                destination_uri,
                extract_job.error_result
            )
        )
        return False
    # Feedback including the compressed folder size and the storage class
    gcs_evicted_size_run = '''bash gsutil du -sc {gcs_evicted_folder} | grep total | cut -d " " -f1 | tr -d \'[:space:]\''''
    gcs_evicted_size = subprocess.check_output(gcs_evicted_size_run.format(
                gcs_evicted_folder = gcs_evicted_folder),
                shell=True, 
                universal_newlines=True)
    gcs_evicted_storage_class_run = '''bash gsutil ls -L -b {gcs_evicted_schema} | grep "Storage class:" | cut -d ":" -f2 |  tr -d \'[:space:]\' '''
    gcs_evicted_storage_class = subprocess.check_output(gcs_evicted_storage_class_run.format(
                gcs_evicted_schema = gcs_evicted_schema),
                shell=True, 
                universal_newlines=True)
    log_msg(
        "Exported {}:{}.{} to {} into storgae class : {} with size : {} Bytes using eviction policy GCS_{}".format(
            get_gcp_project(),
            dataset_id,
            table_id,
            destination_uri,
            gcs_evicted_storage_class,
            gcs_evicted_size,
            eviction_policy
        )
    )
    aws_transfer_folder = ("/{}/{}/{}/").format(
                dataset_id,
                table_id,
                time_delta)
    f = open( '/bq-to-aws-transfer/logs/destination_uri.txt', 'w' )
    f.write(gcs_evicted_folder)
    f.close()
    f1 = open( '/bq-to-aws-transfer/logs/aws_transfer_folder.txt', 'w' )
    f1.write(aws_transfer_folder)
    f1.close()
    return True
    # That's it, or I hope so

def random_string(strLength=10):
    """
    This was taken from the Internet, and it just generates a random
    string of fixed length to be used later when generating seed data
    for temporary tables created during the Unit Tests.
    """
    letters = string.ascii_letters
    return ''.join(
        random.choice(letters) for i in range(strLength)
    )

def log_msg(message):
    """
    Prints a log message to the stderr
    """
    current_frame = inspect.currentframe()
    caller_frame = inspect.getouterframes(current_frame, 2)
    timestamp = datetime.today().strftime("%Y%m%d %H%M%S.%f")
    caller_name = "{}:{}:{}()".format(
        caller_frame[1][1],
        caller_frame[1][2],
        caller_frame[1][3],
    )
    stderr.write("[{}] [{}] {}\n".format(
        timestamp,
        caller_name,
        message
    ))

def cleanup_tests(dataset_id):
    # Deletes the temporary dataset
    client = get_bq_client()
    client.delete_dataset(
        dataset_id,
        delete_contents=True,
        not_found_ok=True
    )
    log_msg("Deleted dataset '{}'.".format(dataset_id))
    # Deletes the GCS objects
    gcs_client = get_gcs_client()
    bucket = gcs_client.get_bucket(get_gcs_bucket())
    for blob in bucket.list_blobs(prefix='test_evictions/'):
        try:
            blob.delete()
        except exceptions.NotFound:
            log_msg("Failed to deleted {} from GCS.".format(
                    blob.id
                )
            )
        else:
            log_msg("{} was deleted from GCS.".format(
                    blob.id
                )
            )