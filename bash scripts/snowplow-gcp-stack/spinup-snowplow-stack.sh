#!/bin/bash 
# Script deploys Snowplow Components such as collector, enricher, stream-loader, mutator and repeater on an existing GKE cluster.
# Make sure that you have created and pushed the enricher and DBT image(https://github.com/newscorp-ghfb/ncgus-data-pipeline-newsnyp.git) before you run this script.
# SCRIPT USAGE 'bash spinup-snowplow-stack.sh'

set -e

project=`jq -r '.source_project' ./snowplow-infra-config.json`
bu=`jq -r '.bu' ./snowplow-infra-config.json`
env=`jq -r '.env' ./snowplow-infra-config.json`
source_enricher_db_bucket=`jq -r '.source_enricher_db_bucket' ./snowplow-infra-config.json`
destination_enricher_db_bucket=`jq -r '.destination_enricher_db_bucket' ./snowplow-infra-config.json`
source_iglu_schemas_bucket=`jq -r '.source_iglu_schemas_bucket' ./snowplow-infra-config.json`
destination_iglu_schemas_bucket=`jq -r '.destination_iglu_schemas_bucket' ./snowplow-infra-config.json`
gke_snowplow_cluster=`jq -r '.gke_snowplow_cluster' ./snowplow-infra-config.json`
gke_cluster_region=`jq -r '.gke_cluster_region' ./snowplow-infra-config.json`
keybase_secrets_repo=`jq -r '.keybase_secrets_repo' ./snowplow-infra-config.json`
collector_domain_name=`jq -r '.collector_domain_name' ./snowplow-infra-config.json`

# set the correct project
gcloud config set project ${project}

# Copy all the MMDB files from newsid-dev
gsutil -m cp -r 'gs://'${source_enricher_db_bucket}'/*' gs://${destination_enricher_db_bucket}
gsutil -m acl -r ch -u AllUsers:R gs://${destination_enricher_db_bucket}

# Copy all the iglu schema files from newsid-dev
gsutil -m cp -r 'gs://'${source_iglu_schemas_bucket}'/*' gs://${destination_iglu_schemas_bucket}
gsutil -m acl -r ch -u AllUsers:R gs://${destination_iglu_schemas_bucket}

# BQ copy tables from newsid-dev
while read line;
do 
    dataset=`echo ${line} | awk -F ":" '{print $2}' | awk -F "." '{print $1}'`
    table=`echo ${line} | awk -F ":" '{print $2}' | awk -F "." '{print $2}'`
    bq cp -f ${line} ${project}:${dataset}.${table}
done < ./bq-table-copy-list.txt


# Set the correct cluster
gcloud container clusters get-credentials ${gke_snowplow_cluster} --region ${gke_cluster_region} --project ${project}

# Create dbt_secret
bash ./get-secrets.sh ${keybase_secrets_repo}
kubectl create secret generic dbt-secret-key --from-file=credentials.json="secrets-${keybase_secrets_repo}/kubernetes/credentials.json" --dry-run=client -o yaml | kubectl apply -f - 

# Reserve Snowplow Collector External IP address for LB
gcloud compute addresses create snowplow-collector-lb-ip --global --ip-version IPV4
collector_lb_ip=`gcloud compute addresses describe snowplow-collector-lb-ip --global | grep address: | awk -F " " '{print $2}'`

# Update aws route53 template file with domain and ip values
sed "s/DOMAIN_NAME_VALUE/$collector_domain_name/g;s/IP_ADDR_VALUE/$collector_lb_ip/g" ./aws-route53-template.json > ./aws-route53-collector-${env}.json

# Update aws route53 hosted zone[data.newscorp.com] by adding collector LB ip 
aws route53 change-resource-record-sets --hosted-zone-id Z0985749W704U90WXG29 --change-batch file://aws-route53-collector-${env}.json
rm -rf ./aws-route53-collector-${env}.json

# create snowplow namespace
kubectl create -f ../../gcp-deployments.snowplow/kubernetes/namespace/snowplow.yml

# Deploy gke configmaps used by snowplow components
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/configmaps/collector-configmap.yml
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/configmaps/loader-configmap.yml
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/configmaps/resolver-configmap.yml

# Deploy snowplow collector 
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/collector-deployment.yml
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/collector-hpa.yml

# Deploy collector service
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/services-ingress/collector-service.yml

# Deploy collector google managed certificate
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/services-ingress/collector-managed-cert.yml

# Deploy collector ingress
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/services-ingress/collector-ingress.yml

# Deploy snowplow enricher
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/enricher-deployment.yml
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/enricher-hpa.yml

# Deploy snowplow stream-loader
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/stream-loader-deployment.yml
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/stream-loader-hpa.yml

# Deploy snowplow mutator
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/mutator-deployment.yml

# Deploy snowplow repeater
kubectl create -f ../../gcp-deployments/snowplow/kubernetes/deployments/repeater-deployment.yml

