#/bin/bash

set -e

cat bq-to-aws-transfer.tmpl | \
sed 's/${PROJECT_ID}'"/$PROJECT_ID/g" | \
sed 's/${COMMIT_SHA}'"/$COMMIT_SHA/g" | \
sed 's/${ENV}'"/$ENV/g" > bq-to-aws-transfer.yaml