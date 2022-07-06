"""Beam code for extracting data from BQ to NDJSON GZip"""

from __future__ import absolute_import

import argparse
import logging

import apache_beam as beam

from apache_beam import io
from apache_beam.io.filesystem import CompressionTypes
from apache_beam.options.pipeline_options import PipelineOptions
import simplejson


def run(argv=None):
    """Main entry point: defines and runs the BQ extraction pipeline"""
    parser = argparse.ArgumentParser()
    # custom arguments for bigquery SQL and GCS output location
    parser.add_argument('--bql',
                        dest='bql',
                        help='bigquery sql to extract req columns and rows.')
    parser.add_argument('--output',
                        dest='output',
                        help='gcs output location for parquet files.')
    known_args, pipeline_args = parser.parse_known_args(argv)
    options = PipelineOptions(pipeline_args)

    # instantiate a pipeline with all the pipeline option
    p = beam.Pipeline(options=options)
    # processing and structure of pipeline
    p \
    | 'Input: QueryTable' >> beam.io.Read(beam.io.BigQuerySource(
        query=known_args.bql,
        use_standard_sql=True)) \
    | "To JSON" >> beam.Map(lambda row: simplejson.dumps(row)) \
    | 'Dump as NDJSON GZip' >> io.textio.WriteToText(
        compression_type=CompressionTypes.AUTO,
        file_path_prefix=known_args.output,
        file_name_suffix=".json.gz")

    result = p.run()
    #result.wait_until_finish()  # Makes job to display all the logs


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
