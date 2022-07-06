FROM debian:stretch

ENV gcloud_ver=221.0.0-0

# Install misc packages
RUN set -ex; \
      apt-get update \
      && apt-get -y install gnupg htop nano procps git wget curl

# Install gsutil
COPY google-cloud-sdk.list apt-key.gpg /tmp/
RUN set -ex; \
      mv /tmp/google-cloud-sdk.list /etc/apt/sources.list.d/ \
      && apt-key add /tmp/apt-key.gpg \
      && rm /tmp/apt-key.gpg \
      && apt-get update \
      && apt-get install -y google-cloud-sdk=$gcloud_ver

COPY bqtable_deletion_policy.sh /root/scripts/bqtable_deletion_policy.sh
COPY table_deletion_policy.txt /root/scripts/table_deletion_policy.txt


RUN chmod +x /root/scripts/bqtable_deletion_policy.sh

WORKDIR /root/scripts/