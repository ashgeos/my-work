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

def get_gcp_project():
    """
    Obtains the GCP project name from the environment or defaults
    to DEV otherwise.
    """
    return getenv('NEWSIQ_GCP_PROJECT', 'newscorp-newsiq-dev')

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
    return "newscorp-newsiq-bq-evictions-{}".format(environ)

def backup_existent_gcs(dataset, table_id):
    gcs_client = get_gcs_client()
    bucket = gcs_client.get_bucket(get_gcs_bucket())
    time_delta = datetime.today().strftime('%Y%m%d%H%M%S')
    for old_backup in bucket.list_blobs(prefix="{}/{}".format(
        dataset,
        table_id
    )):
        if old_backup.name.endswith('.json.gz'):
            log_msg("Copying already existent backup {}".format(old_backup))
            bucket.rename_blob(old_backup, "{}/{}/{}/{}".format(
                dataset,
                old_backup.name.split('/')[-2],
                time_delta,
                old_backup.name.split('/').pop()
            ))
"""
#This peice of code will not be used as the cost incurred from google is very high, but still keeping it in case its planned to be used
# in the future.
def extract_to_gcs(dataset_id, table_id):
    client = get_bq_client()
    gcs_client = get_gcs_client()
    # Proceeds with the extract
    table_id = table_id
    dataset_id = dataset_id
    project = get_gcp_project()
    # Obtains the table references
    dataset_ref = client.dataset(dataset_id, project=get_gcp_project())
    table_ref = dataset_ref.table(table_id)
    gcs_bucket = get_gcs_bucket()
    # backups any already existent backups for this table
    # this could happen if for example we are processing a
    # table that was restored from GCS from its backup and
    # now we are evicting that same table again.
    backup_existent_gcs(dataset_id, table_id)
    # Extracts the Schema
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
    blob = storage.Blob("{}/{}/schema.txt".format(
            dataset_id,
            table_id
        ),
        bucket
    )
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
    
    # Starts a Dataflow pipeline job to extract BQ table and dump it to GCS
    # pypath needs to be set to the working python path where this script will be executing.
    # policylocation needs to be set to the exact path of the bq_table_to_gcs.sh script.
    pypath = getenv('NEWSIQ_GCP_EVICTION_PYTHON2_PATH', '/usr/lib/python2.7/bin/python')
    policylocation = getenv('NEWSIQ_GCP_EVICTION_POLICY_LOCATION', '/eviction/policies')
    workercount = getenv('NEWSIQ_GCP_DF_WORKER_COUNT', '40')
    maxworkercount = getenv('NEWSIQ_GCP_DF_MAX_WORKER_COUNT', '100')
    statuslocation = getenv('NEWSIQ_GCP_EVICTION_STATUS_LOCATION', '/eviction/logs')

    eviction_bash = '''sh {policylocation}/bq_table_to_gcs.sh -p {project} {gcs_bucket} {table_id} {dataset_id} -n {pypath} {workercount} {maxworkercount}'''
    
    subprocess.check_call(eviction_bash.format(policylocation=policylocation,
    project=project,
    gcs_bucket=gcs_bucket,
    table_id=table_id,
    dataset_id=dataset_id,
    pypath=pypath,
    workercount=workercount,
    maxworkercount=maxworkercount),
    shell=True)

    # jobfile will created by the above bash script with values either True(If the extraction is success) or False(if the extraction is a Failure/Cancelled/Running) 
    jobfile='{statuslocation}/jobstatusenv'
    try:
        line=open(jobfile).readline()
    except IOError:
      print "Error: {jobfile} File does not appear to exist."
      return False
    jobstatus=line.strip()   
    if jobstatus == 'False':
        # Feedback
        log_msg(
            "Failed to export {}:{}.{}".format(
                get_gcp_project(),
                dataset_id,
                table_id
            )
        )
        return False
    if jobstatus == 'True':   
        log_msg(
            "Sucessfully Exported {}:{}.{}".format(
                get_gcp_project(),
                dataset_id,
                table_id
            )
        )
        return True
"""

def extract_to_gcs(dataset_id, table_id, eviction_policy, backup=True, isNormal=True, isDayPartitioned=False):
    """
    Extracts the contents from the table specified on the parameters
    to a bucket in GCS.
    """
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
        backup_existent_gcs(dataset_id, table_id)
    # Extracts the Schema
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
    # That's it, or I hope so
    return True

def delete_table(dataset_id, table_id, eviction_policy, evict=True):
    """
    This method is used across all policies when deleting a table is
    required so that it can be done consistently.
    """
    client = get_bq_client()
    # deletes the table
    # but only if we are sure we have its backup
    if evict:
        if extract_to_gcs(dataset_id, table_id, eviction_policy):
            client.delete_table("{}.{}".format(
                dataset_id,
                table_id
            ), not_found_ok=True)
            log_msg("Table {} *has been* evicted and deleted.".format(
                    table_id
                )
            )
        else:
            log_msg("Failed to backup table {} to GCS.".format(
                    table_id
                )
            )
            log_msg("Aborting deleting the table.")
    else:
        client.delete_table("{}.{}".format(
            dataset_id,
            table_id
        ), not_found_ok=True)
        log_msg("Table {} *has been* deleted.".format(
                table_id
            )
        )

def delete_table_with_retention(dataset_id, table_id, retention_period, eviction_policy, dry_run, evict=True):

    """
    Gets a list of tables to be deleted from BQ that found out from the retention policy set on table level.
    """
    project = get_gcp_project()
    downstream_buffer = getenv('NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER', '3')
    # deletes the table
    statuslocation = getenv('NEWSIQ_GCP_EVICTION_LOG_LOCATION', '/eviction/logs')
    policylocation = getenv('NEWSIQ_GCP_EVICTION_POLICY_LOCATION', '/eviction/policies')
    table_id = table_id
    retention_period = retention_period
    eviction_with_retention_bash = '''bash {policylocation}/find_tables_for_deletion_with_retention.sh {dry_run} {project} {downstream_buffer} {dataset_id} {table_id} {retention_period} {statuslocation} {eviction_policy}'''
    
    subprocess.check_call(eviction_with_retention_bash.format(policylocation=policylocation,
    dry_run=dry_run,
    project=project,
    downstream_buffer=downstream_buffer,
    dataset_id=dataset_id,
    table_id=table_id,
    retention_period=retention_period,
    statuslocation=statuslocation,
    eviction_policy=eviction_policy),
    shell=True)

    jobfile="{}/deletionjobstatusenv".format(statuslocation)
    try:
        lines=open(jobfile).readlines()
    except IOError:
      print "Error: {jobfile} File does not appear to exist."
      return False
    for line in lines:
        table_id, table_status = line.split(':')
        table_id=table_id.strip()
        table_status=table_status.strip()
        if table_status == 'true':   
            log_msg(
                "Table is marked for deletion {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
            delete_table(dataset_id, table_id, eviction_policy, evict=False)
        elif table_status == 'skipped':   
            log_msg(
                "Table Skipped from deletion as the table is modified recently, computed using downstream_buffer {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'deleted':
            log_msg(
                "Partition Table is deleted {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'dry_run':   
            log_msg(
                "Table will be deleted without being evicted {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'no_tables_to_delete':   
            log_msg(
                "There are no tables to be deleted under {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
    os.remove(jobfile)
    return True

def evict_and_delete_table_with_retention(dataset_id, table_id, retention_period, eviction_policy, dry_run, evict=True):
    """
    Gets a list of tables to be evicted to GCS and deleted from BQ that found out from the retention policy set on table level.
    """
    project = get_gcp_project()
    downstream_buffer = getenv('NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER', '3')
    # deletes the table
    statuslocation = getenv('NEWSIQ_GCP_EVICTION_LOG_LOCATION', '/eviction/logs')
    policylocation = getenv('NEWSIQ_GCP_EVICTION_POLICY_LOCATION', '/eviction/policies')
    table_id = table_id
    retention_period = retention_period
    eviction_with_retention_bash = '''bash {policylocation}/find_tables_for_deletion_with_retention.sh {dry_run} {project} {downstream_buffer} {dataset_id} {table_id} {retention_period} {statuslocation} {eviction_policy}'''
    
    subprocess.check_call(eviction_with_retention_bash.format(policylocation=policylocation,
    dry_run=dry_run,
    project=project,
    downstream_buffer=downstream_buffer,
    dataset_id=dataset_id,
    table_id=table_id,
    retention_period=retention_period,
    statuslocation=statuslocation,
    eviction_policy=eviction_policy),
    shell=True)

    jobfile="{}/deletionjobstatusenv".format(statuslocation)
    try:
        lines=open(jobfile).readlines()
    except IOError:
      print "Error: {jobfile} File does not appear to exist."
      return False
    for line in lines:
        table_id, table_status = line.split(':')
        table_id=table_id.strip()
        table_status=table_status.strip()
        if table_status == 'true':   
            log_msg(
                "Table is marked for eviction and deletion {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
            delete_table(dataset_id, table_id, eviction_policy)
        elif table_status == 'evictAndDeletePartitioned':   
            if extract_to_gcs(dataset_id, table_id, eviction_policy, isNormal=False, isDayPartitioned=True):
                delete_table(dataset_id, table_id, eviction_policy, evict=False)
                log_msg(
                "Partitioned table is evicted and deleted {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'skipped':   
            log_msg(
                "Table Skipped from deletion as the table is modified recently, computed using downstream_buffer {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'dry_run':   
            log_msg(
                "Table will be evicted and deleted {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'no_tables_to_delete':   
            log_msg(
                "There are no tables to be deleted under {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
    os.remove(jobfile)
    return True

def evict_only_no_delete_table_with_retention(dataset_id, table_id, retention_period, eviction_policy, dry_run, evict=True):
    """
    Gets a list of tables to be evicted from BQ that found out from the retention policy set on table level.
    """
    project = get_gcp_project()
    downstream_buffer = getenv('NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER', '3')
    # deletes the table
    statuslocation = getenv('NEWSIQ_GCP_EVICTION_LOG_LOCATION', '/eviction/logs')
    policylocation = getenv('NEWSIQ_GCP_EVICTION_POLICY_LOCATION', '/eviction/policies')
    table_id = table_id
    retention_period = retention_period
    eviction_with_retention_bash = '''bash {policylocation}/find_tables_for_deletion_with_retention.sh {dry_run} {project} {downstream_buffer} {dataset_id} {table_id} {retention_period} {statuslocation} {eviction_policy}'''
    
    subprocess.check_call(eviction_with_retention_bash.format(policylocation=policylocation,
    dry_run=dry_run,
    project=project,
    downstream_buffer=downstream_buffer,
    dataset_id=dataset_id,
    table_id=table_id,
    retention_period=retention_period,
    statuslocation=statuslocation,
    eviction_policy=eviction_policy),
    shell=True)

    jobfile="{}/deletionjobstatusenv".format(statuslocation)
    try:
        lines=open(jobfile).readlines()
    except IOError:
      print "Error: {jobfile} File does not appear to exist."
      return False
    for line in lines:
        table_id, table_status = line.split(':')
        table_id=table_id.strip()
        table_status=table_status.strip()
        if (table_status == 'backuponlyNormal') or (table_status == 'true'):   
            log_msg(
                "Table is marked for eviction {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
            if extract_to_gcs(dataset_id, table_id, eviction_policy):
                log_msg("Table {} *has been* evicted Sucessfully.".format(
                    table_id
                    )
                )
            else:
                log_msg("Failed to backup table {} to GCS.".format(
                    table_id
                    )
                )
        elif table_status == 'backuponlyPartitioned':   
            log_msg(
                "Partitioned Table is marked for eviction {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
            if extract_to_gcs(dataset_id, table_id, eviction_policy, backup=False, isNormal=False):
                log_msg("Partitioned Table {} *has been* evicted Sucessfully.".format(
                    table_id
                    )
                )
            else:
                log_msg("Failed to backup table {} to GCS.".format(
                    table_id
                    )
                )
        elif table_status == 'dry_run':   
            log_msg(
                "Table will be evicted {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
        elif table_status == 'no_tables_to_delete':   
            log_msg(
                "There are no tables to be evicted under {}:{}.{}".format(
                    get_gcp_project(),
                    dataset_id,
                    table_id
                )
            )
    os.remove(jobfile)
    return True


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