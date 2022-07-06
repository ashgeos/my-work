import sys
import yaml
import re
from os import getenv
from policies import keep_everything
from policies import keep_latest_only
from policies import restore_from_gcs
from policies import delete_and_evict
from policies import delete_no_eviction
from policies import eviction_no_delete
from policies import partitioned_delete_no_eviction
from policies import log_msg

def load_configuration(yaml_string=''):
    """
    Loads the YAML configuration that dictates what to do with the
    BigQuery tables. This by default reads from the eviction.yml file
    in the same directory. It accepts a YAML string that will be used
    instead of thedefault configuration file.
    """
    if yaml_string:
        stream = yaml_string
    else:
        stream = file('eviction.yml', 'r')
    try:
        config = yaml.load(stream)
    except yaml.scanner.ScannerError:
        log_msg("eviction.yml file is not valid")
        return False
    except yaml.parser.ParserError:
        log_msg("eviction.yml file contains errors")
        return False
    except:
        log_msg("errors found while parsing eviction.yml")
        return False
    else:
        return config

def apply_policies(config):
    """
    Applies the policies specified in the YAML configuration by
    dinamycally calling a module from the policies package, the
    module must match the policy name as specified in the YAML
    configuration.
    """
    dry_run = getenv('NEWSIQ_BQ_EVICTION_DRY_RUN', True)
    for dataset, tables in config.iteritems():
        for table, policy in tables.iteritems():
            if "delete_no_eviction" in policy:
                if table.endswith('_') or "delete_no_eviction:" in policy:
                    policy, retention_period= policy.split(":")
                    policy = policy.strip()
                    retention_period = retention_period.strip()
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )
                else:
                    retention_period = "false"
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )
            elif "delete_and_evict" in policy:
                if table.endswith('_') or "delete_and_evict:" in policy:
                    policy, retention_period= policy.split(":")
                    policy = policy.strip()
                    retention_period = retention_period.strip()
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )
                else:
                    retention_period = "false"
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )
            elif "partitioned_delete_no_eviction" in policy:
                policy, retention_period= policy.split(":")
                policy = policy.strip()
                retention_period = retention_period.strip()
                getattr(sys.modules["policies.%s" % policy], "apply")(
                dataset,
                table,
                retention_period,
                dry_run
                )
            elif "eviction_no_delete" in policy:
                #For a specifc normal table ending with a date.
                # Eg ad_value_summary_20191209: eviction_no_delete
                if  re.search(r'\d+$', table):
                    retention_period = "false"
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )
                #For a day partitioned table with rentention policy "daily"
                # Eg adx_dealid: eviction_no_delete:daily
                else:
                    policy, retention_period= policy.split(":")
                    policy = policy.strip()
                    retention_period = retention_period.strip()
                    getattr(sys.modules["policies.%s" % policy], "apply")(
                    dataset,
                    table,
                    retention_period,
                    dry_run
                    )                  
            else:
                getattr(sys.modules["policies.%s" % policy], "apply")(
                dataset,
                table,
                dry_run
                )
                
            
if __name__ == '__main__':
    config = load_configuration()
    if config:
        apply_policies(config)
