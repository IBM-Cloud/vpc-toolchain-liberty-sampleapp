#! /usr/bin/env bash
set -eo pipefail

echo -n "${PRIVATE_KEY}" | base64 -d > ssh_private_key && chmod 400 ssh_private_key

echo "BUILD_NUMBER=${BUILD_NUMBER}"
echo "ARCHIVE_DIR=${ARCHIVE_DIR}"

GIT_REMOTE_URL=$(git config --get remote.origin.url)

echo "TF_VAR_ibmcloud_api_key=${TF_VAR_ibmcloud_api_key}" >> build.properties
echo "TF_VAR_vpc_region=${TF_VAR_vpc_region}" >> build.properties
echo "TF_VAR_vpc_ssh_keys=[\"${TF_VAR_vpc_ssh_keys}\"]" >> build.properties
echo "TF_VAR_vpc_resource_group=${TF_VAR_vpc_resource_group}" >> build.properties
echo "TF_VAR_vpc_resources_prefix=${TF_VAR_vpc_resources_prefix}" >> build.properties

echo "GIT_URL=${GIT_URL}" >> build.properties
echo "GIT_BRANCH=${GIT_BRANCH}" >> build.properties
echo "GIT_COMMIT=${GIT_COMMIT}" >> build.properties
echo "GIT_REMOTE_URL=${GIT_REMOTE_URL}" >> build.properties
echo "SOURCE_BUILD_NUMBER=${BUILD_NUMBER}" >> build.properties

# package app for VSI deployment
mvn clean install
target/liberty/wlp/bin/server package defaultServer --archive="sampleapp" --include=minify
if [ ! -f target/liberty/wlp/usr/servers/defaultServer/sampleapp.zip ]; then echo "Package was not successfully created."; exit 1; fi