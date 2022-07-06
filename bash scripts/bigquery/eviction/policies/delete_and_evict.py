from sys import stderr
from . import get_bq_client
from . import get_gcp_project
from . import table_name_matches
from . import delete_table
from . import evict_and_delete_table_with_retention
from . import log_msg

def apply(dataset, table_name, retention_period, dry_run = False):
    """
    Deletes all the tables in the dataset passed as parameter when the
    table names match the given table name as per the
    table_name_matches function. 
    NOTE : Only give normal and "day" partitioned tables are handled in this policy, tables partitioned with "_PARTITIONTIME" 
    is not handled in this policy.
    Eg adx_dealid: delete_and_evict:daily@90 -> for day partitioned table
    Eg Eg ad_value_summary_: delete_and_evict:90 -> for a normal table
    """
    retention_period = retention_period
    eviction_policy = "delete_and_evict"
    if retention_period == "false":
        client = get_bq_client()
        dataset_id = "{}.{}".format(get_gcp_project(), dataset)
        tables = client.list_tables(dataset_id, max_results=100000)
        # Processes the dataset tables looking for matches
        for table in tables:
            if table_name_matches(table, table_name):
                if dry_run == "True":
                    log_msg("Table {} *would be* evicted and deleted as per dry_run.".format(
                            table.table_id
                        )
                    )
                # evicts and deletes the table    
                elif dry_run == "False":
                    delete_table(dataset, table.table_id, eviction_policy)
                else:
                    print "dry_run vlaue missing"
    else:
        evict_and_delete_table_with_retention(dataset, table_name, retention_period, eviction_policy, dry_run)