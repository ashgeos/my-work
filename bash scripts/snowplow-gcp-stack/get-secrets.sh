#!/bin/bash -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"

keybase_secrets_repo=$1

if [[ ! -e "secrets-${keybase_secrets_repo}" ]]; then
    git clone keybase://team/newsid/${keybase_secrets_repo} secrets-${keybase_secrets_repo}
else
    pushd secrets-${keybase_secrets_repo}
    git pull
    popd
fi
