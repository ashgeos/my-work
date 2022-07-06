import sys
import yaml
import re
from os import getenv
from policies import eviction_aws_no_delete
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
            if "eviction_aws_no_delete" in policy:
                #For any table
                retention_period = "false"
                getattr(sys.modules["policies.%s" % policy], "apply")(
                dataset,
                table,
                retention_period,
                dry_run
                )          
            else:
               log_msg("Only eviction_aws_no_delete policy works for this script")
            
if __name__ == '__main__':
    config = load_configuration()
    if config:
        apply_policies(config)
