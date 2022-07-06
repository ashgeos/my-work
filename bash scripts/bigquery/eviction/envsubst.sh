#/bin/bash

set -e

cat bq-eviction.tmpl | \
sed 's/${PROJECT_ID}'"/$PROJECT_ID/g" | \
sed 's/${COMMIT_SHA}'"/$COMMIT_SHA/g" | \
sed 's/${ENV}'"/$ENV/g" > bq-eviction.yaml