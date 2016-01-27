#!/bin/bash
# fail on errors
set -e

CLOUDSDK_URL=https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
SDK_DIR=google-cloud-sdk
export PATH=$SDK_DIR/bin:$PATH

# don't let gcloud prompt: there's no human on the other end
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export CLOUDSDK_PYTHON_SITEPACKAGES=1

# make sure gcloud SDK is installed
if [ ! -d $SDK_DIR ]; then
  mkdir -p $SDK_DIR
  curl -o /tmp/gcloud.tar.gz $CLOUDSDK_URL
  tar xzf /tmp/gcloud.tar.gz --strip 1 -C $SDK_DIR
  $SDK_DIR/install.sh
fi

# authenticate user a service account in this repo
# and configure gcloud: this will authenticate gsutil as well
openssl aes-256-cbc -d -k $SERVICE_SECRET \
        -in tools/web-central-44673aab0806.json.enc \
        -out tools/web-central-44673aab0806.json
gcloud config set project web-central
gcloud auth activate-service-account $SERVICE_ACCOUNT \
        --key-file tools/web-central-44673aab0806.json \
        --quiet

# construct the bucket name:
# - for pull requests it starts with pr-<number>
# - others are just commits to a branch, so pr-<branch-name>
BUCKET=$CI_BRANCH
if [ -n "$CI_PULL_REQUEST" ]; then
	BUCKET=pr-$CI_PULL_REQUEST
fi
# since bucket names are global, append a unique suffix
# most likely noone else will have.
# if you change the suffix, make sure to do so in server/ as well.
BUCKET=gs://$BUCKET-webcentral-appspot-weasel

# the bucket may already exist. create if it doesn't.
gsutil ls $BUCKET > /dev/null || true
if [ "$PIPESTATUS[0]" != "0" ]; then
	gsutil mb -c DRA $BUCKET || exit 1
fi
# copy everything from ./build to the bucket
gsutil -m cp -r ./build/* $BUCKET
