import sys
from . import log_msg

def apply(dataset, table_name, dry_run = False):
    """
    This basically does nothing.
    """
    # informational in case of using the dry_run option
    if dry_run == "True":
        log_msg("Table {} is being kept.".format(table_name))
