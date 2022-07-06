from sys import stderr
from . import get_bq_client
from . import get_gcp_project
from . import table_name_matches
from . import delete_table
from . import log_msg
from google.api_core.exceptions import NotFound

def apply(dataset, table_name, dry_run = False):
    """
    Deletes all the tables in the dataset passed as parameter when the
    table names match the given table name as per the
    table_name_matches function.
    """
    client = get_bq_client()
    dataset_id = "{}.{}".format(get_gcp_project(), dataset)
    tables = client.list_tables(dataset_id, max_results=1000)
    # Processes the dataset tables looking for matches
    try:
        for table in tables:
            if table_name_matches(table, table_name):
                if dry_run:
                    log_msg("Table {} *would be* deleted.".format(
                            table.table_id
                        )
                    )
                else:
                    # deletes the table
                    delete_table(dataset, table.table_id, evict=False)
    except NotFound:
        log_msg(
            "Table {} not found when searching for it for deletion.".format(
                table.table_id
            )
        )
