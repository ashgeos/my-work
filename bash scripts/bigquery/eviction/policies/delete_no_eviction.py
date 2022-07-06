from sys import stderr
from . import get_bq_client
from . import get_gcp_project
from . import table_name_matches
from . import delete_table
from . import delete_table_with_retention
from . import log_msg
from google.api_core.exceptions import NotFound

def apply(dataset, table_name, retention_period, dry_run = False):
    """
    Deletes all the tables in the dataset passed as parameter when the
    table names match the given table name as per the
    table_name_matches function.
    NOTE : Only normal tables are handled in this policy.
    """
    retention_period = retention_period
    eviction_policy = "delete_no_eviction"
    if retention_period == "false":
        client = get_bq_client()
        dataset_id = "{}.{}".format(get_gcp_project(), dataset)
        tables = client.list_tables(dataset_id, max_results=100000)
        # Processes the dataset tables looking for matches
        try:
            for table in tables:
                if table_name_matches(table, table_name):
                    if dry_run == "True":
                        log_msg("Table {} *would be* deleted as per dry_run.".format(
                                table.table_id
                            )
                        )
                    elif dry_run == "False":
                        # deletes the table
                        delete_table(dataset, table.table_id, eviction_policy, evict=False)
                    else:
                        print "dry_run vlaue missing"
        except NotFound:
            log_msg(
                "Table {} not found when searching for it for deletion.".format(
                    table.table_id
                )
            )
    else:
        delete_table_with_retention(dataset, table_name, retention_period, eviction_policy, dry_run)
