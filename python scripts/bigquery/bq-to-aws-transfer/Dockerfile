FROM python:2

ENV gcloud_ver=221.0.0-0 
RUN set -ex; \
      apt-get update -y \
      && apt-get -y install gnupg 

# Install gsutil
COPY docker/google-cloud-sdk.list docker/apt-key.gpg /tmp/
RUN set -ex; \
      mv /tmp/google-cloud-sdk.list /etc/apt/sources.list.d/ \
      && apt-key add /tmp/apt-key.gpg \
      && rm /tmp/apt-key.gpg \
      && apt-get install -y jq awscli \
      && apt-get update -y \
      && apt-get install -y google-cloud-sdk=$gcloud_ver \
      && apt-get --only-upgrade install -y kubectl google-cloud-sdk

WORKDIR /bq-to-aws-transfer
COPY . /bq-to-aws-transfer
RUN mkdir -p /bq-to-aws-transfer/logs
RUN python2 -m pip install --upgrade pip
RUN set -ex; \
      pip install --no-cache-dir -r requirements.txt