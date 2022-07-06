from sys import stderr
from . import delete_table_with_retention

def apply(dataset, table_name, retention_period, dry_run = False):
    """
    Deletes all the tables in the dataset passed as parameter when the
    table names match the given table name as per the
    table_name_matches function.
    NOTE : Only tables partitioned with "_PARTITIONTIME" is handled in this policy.
    """
    retention_period = retention_period
    eviction_policy = "partitioned_delete_no_eviction"
    delete_table_with_retention(dataset, table_name, retention_period, eviction_policy, dry_run)