from re import search
from sys import stderr
from sys import exc_info
from ast import literal_eval
from . import get_bq_client
from . import get_gcp_project
from . import get_gcs_client
from . import get_gcs_bucket
from . import log_msg
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError
from google.api_core.exceptions import NotFound

def apply(dataset, table_name, dry_run = False):
    """
    Tries to recover a table from Google Storage
    """
    client = get_bq_client()
    gcs_client = get_gcs_client()
    # obtains the backup blobs
    bucket = gcs_client.get_bucket(get_gcs_bucket())
    location_prefix = "{}/{}".format(
        dataset,
        table_name
    )
    table_blobs = {}
    for backup_blob in bucket.list_blobs(prefix=location_prefix):
        # do not process backup backups
        if not search(r'\/\d{14}\/', backup_blob.name):
            t_name = backup_blob.name.split('/')[1]
            if t_name not in table_blobs:
                table_blobs[t_name] = {}
            if 'blobs' not in table_blobs[t_name]:
                table_blobs[t_name]['blobs'] = []
            if backup_blob.name.endswith('schema.txt'):
                table_blobs[t_name]['schema'] = backup_blob
            else:
                table_blobs[t_name]['blobs'].append(backup_blob)
    # common load job configuration for all loads
    src_fmt = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
    job_config = bigquery.LoadJobConfig()
    job_config.source_format = src_fmt
    # process the table backups found to try to recover them
    for table_id, table_backup in table_blobs.iteritems():
        # Checks if the table exists
        try:
            client.get_table("{}.{}.{}".format(
                    get_gcp_project(),
                    dataset,
                    table_id
                )
            )
        except NotFound:
            if table_backup['schema']:
                table = None
                try:
                    # Creates the table based on the schema
                    table = bigquery.Table.from_api_repr(
                        literal_eval(
                            table_backup['schema'].download_as_string()
                        )
                    )
                except KeyError:
                    log_msg("Error parsing {} schema.".format(
                            table_id
                        )
                    )
                    log_msg('Aborting recovering the table.')
                except TypeError:
                    log_msg("Error parsing the schema: {}".format(
                        exc_info()[0]
                    ))
                if table:
                    bq_table = client.create_table(table)
                    # Loads the data
                    for table_blob in table_backup['blobs']:
                        load_job = client.load_table_from_uri(
                            "gs://{}/{}".format(
                                bucket.name,
                                table_blob.name
                            ),
                            bq_table,
                            location='US',
                            job_config=job_config
                        )
                        try:
                            load_job.result()
                        except GoogleCloudError:
                            log_msg("Failed to load table {}.".format(
                                    bq_table.table_id
                                )
                            )
                            log_msg("From: {}.".format(
                                    table_blob.self_link
                                )
                            )
                            log_msg("Reason: {}.".format(
                                    load_job.error_result
                                )
                            )
                        else:
                            log_msg("Successfully loaded table {}".format(
                                        bq_table.table_id
                                    )
                            )
                            log_msg("From: {}".format(
                                        table_blob.self_link
                                    )
                            )
            else:
                log_msg("Schema file for {} table was not found.".format(
                        table_id
                    )
                )
                log_msg("Aborting recovering the table.")
        else:
            log_msg("The table {} was found already existent.".format(
                    table_id
                )
            )
            log_msg("Aborting recovering the table.")
