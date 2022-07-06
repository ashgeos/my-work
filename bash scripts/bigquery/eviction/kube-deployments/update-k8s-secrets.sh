#!/bin/bash

# This script can be used to manually update the k8s secrets when needed.
# Keep in mind that while the secrets mounted in the pods will be updated,
# airflow won't pick the changes until the service is restarted (the easiest way
# to do this is by triggering a deploy with CloudBuild). If you just want to
# update some secrets for airflow, run the CloudBuild, there is no need
# to manually run this script.

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
WHITE='\033[0;37m'
cd "$( dirname "${BASH_SOURCE[0]}" )/../.."

echo -e "${ORANGE}Select Cluster Environment"
tput sgr0
options=("newscorp-newsid-dev" "newscorp-newsid-prod")
select opt in "${options[@]}"
do
    tput sgr0
    case $opt in
        "newscorp-newsid-dev")
            ENV='dev'
            gcloud config set project newscorp-newsid-dev
            gcloud config set container/cluster newsid-prod-snowplow-cluster
            gcloud container clusters get-credentials newsid-prod-snowplow-cluster --zone us-central1
            break
            ;;
        "newscorp-newsid-prod")
            ENV='prod'
            gcloud config set project newscorp-newsid-prod
            gcloud config set container/cluster newsid-prod-snowplow-cluster
            gcloud container clusters get-credentials newsid-prod-snowplow-cluster --zone us-central1
            break
            ;;
        *) echo invalid option;;
    esac
done

echo -e "${GREEN}Downloading the latest secret repo from newsid-${ENV} keybase.."
tput sgr0
bash ../../terraform/${ENV}/get-secrets

echo -e "${GREEN}Updating eviction-gcp GKE secret..."
tput sgr0
kubectl --namespace=eviction create secret generic eviction-gcp \
    --from-file=credentials.json=../../terraform/${ENV}/secrets-repo/kubernetes/newscorp-newsid-eviction-service-acc.json \
    --dry-run=client -o yaml | kubectl apply -f - 

echo -e "${GREEN}Deletig local secrets-repo-${ENV} repo folder.."
tput sgr0
rm -rf ../../terraform/${ENV}/secrets-repo
echo -e "${GREEN}Done..."
tput sgr0