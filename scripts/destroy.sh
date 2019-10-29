#! /usr/bin/env bash
set -eo pipefail

function commit_state {
  cd - 
  cd temp_repo

  git config --global user.email "vpc.toolchain@noreply.com"
  git config --global user.name "Automatic Build ibmcloud-vpc-toolchain"
  git config --global push.default simple
  git add .
  git commit -m "Published terraform apply updates from ibmcloud-toolchain"
  git push --set-upstream origin br_tfstate -f
}

function error_save_state {
  set +e
  commit_state
  exit 1
}

mkdir ~/.ssh
cp ssh_private_key ~/.ssh/id_rsa 

rm -rf temp_repo

git clone ${GIT_REMOTE_URL} temp_repo

cd temp_repo

git fetch origin br_tfstate
git checkout br_tfstate

cd - 

cd terraform
rm -rf .terraform
terraform init -input=false
terraform validate

trap error_save_state ERR
# Need to commit the state in the event of a failure and then bail
terraform destroy -input=false -auto-approve -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate

commit_state