import sys
from re import search
from . import get_bq_client
from . import get_gcp_project
from . import table_name_matches
from . import delete_table
from . import log_msg

def apply(dataset, table_name, dry_run = False):
    """
    Deletes all the tables from the passed dataset as parameter when
    they match the given name as per the table_name_matches function,
    except for the latest table. The latest table is defined based on
    the date found at the end of the table name.
    """
    # Connects to GCP
    client = get_bq_client()
    # Defines the dataset id
    dataset_id = "{}.{}".format(get_gcp_project(), dataset)
    # Obtains all the dataset's tables
    tables = client.list_tables(dataset_id, max_results=100000)
    all_tables = list(tables)
    # Processes the dataset tables looking for the latest table
    latest = ''
    matching_tables = []
    for table in all_tables:
        # verifies if the table matches
        if table_name_matches(table, table_name):
            # verifies if it's a date sharded table
            if search('_[0-9]{8}$', table.table_id):
                # obtains the table date
                table_date = table.table_id[(table.table_id.rfind('_') + 1):]
                # stores the latest only for future reference
                if latest < table_date:
                    latest = table_date
                # We will re-process this tables next
                matching_tables.append(table)
    # Deletes all the tables except for the latest
    # But only if we actually figured out which one is the latest.
    if latest:
        for table in matching_tables:
            # obtains the table date
            last_index = (table.table_id.rfind('_') + 1)
            table_date = table.table_id[last_index:]
            # if it's the latest, then ignore it
            if table_date == latest:
                log_msg("Ignoring latest table {}.". format(table.table_id))
                continue
            else:
                # deletes all the other tables
                if dry_run == "True":
                    # Do not delete, just inform
                    log_msg("Table {} *would be* deleted.".format(
                            table.table_id
                        )
                    )
                else:
                    # deletes the table
                    delete_table(dataset, table.table_id)
