FROM python:2

ENV gcloud_ver=334.0.0-0
RUN set -ex; \
      apt-get update -y \
      && apt-get -y install gnupg wget

# Install gsutil
COPY docker/google-cloud-sdk.list docker/apt-key.gpg /tmp/
RUN set -ex; \
      mv /tmp/google-cloud-sdk.list /etc/apt/sources.list.d/ \
      && wget https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      && apt-key add apt-key.gpg \
      && apt-get install -y jq \
      && apt-get update -y \
      && apt-get install -y google-cloud-sdk=$gcloud_ver \
      && apt-get --only-upgrade install -y kubectl google-cloud-sdk

WORKDIR /eviction
COPY . /eviction
RUN python2 -m pip install --upgrade pip
RUN set -ex; \
      pip install --no-cache-dir -r requirements.txt