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

function terraform_apply {
  terraform init -input=false
  terraform validate

  terraform plan -input=false -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate -out=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfplan

  # Need to commit the state in the event of a failure and then bail
  trap error_save_state ERR
  terraform apply -auto-approve -input=false -state-out=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate ../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfplan

  VSI_BASTION_HOST=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "vpc_vsi_bastion_fip")
  VSI_HOST_1=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "vpc_vsi_1_ip")
  VSI_HOST_2=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "vpc_vsi_2_ip")
  VSI_HOST_3=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "vpc_vsi_3_ip")
  VPC_ZONE_COUNT=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "vpc_zone_count")
  LB_HOSTNAME=$(terraform output -state=../temp_repo/state/terraform_${PIPELINE_TOOLCHAIN_ID}.tfstate "lb_public_hostname")
}

function display_access_urls {
  echo "----------------------------------------------------------------------------------------------------------"
  echo "Access the web application using the following url: http://${LB_HOSTNAME}/sampleapp"
  echo ""
  echo "Successfully reached health endpoint: http://${LB_HOSTNAME}/health"
  echo ""
  echo "Access the server using the following url: http://${LB_HOSTNAME}"
  echo "----------------------------------------------------------------------------------------------------------"
}

# adding OpenSSH to allow for scp and ssh commands later on. 
apk update
apk add openssh

mkdir ~/.ssh
cp ssh_private_key ~/.ssh/id_rsa 

git clone ${GIT_REMOTE_URL} temp_repo

cd temp_repo

git ls-remote --heads ${GIT_REMOTE_URL} br_tfstate | wc -l
if [ $(git ls-remote --heads ${GIT_REMOTE_URL} br_tfstate | wc -l) == "0" ]; then
  git checkout --orphan br_tfstate
  git rm -rf .
  git config --global user.email "vpc.toolchain@noreply.com"
  git config --global user.name "Automatic Build ibmcloud-vpc-toolchain"
  git config --global push.default simple
  git commit --allow-empty -m "root commit"
  git push origin br_tfstate
else
  git fetch origin br_tfstate
  git checkout br_tfstate
fi

mkdir -p state

cd -
cd terraform

terraform_apply

commit_state

cd -
cat > ~/.ssh/config <<- EOF
Host $VSI_BASTION_HOST $VSI_HOST_1 $VSI_HOST_2 $VSI_HOST_3
  User root
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
  LogLevel=quiet
  BatchMode=yes
  ConnectTimeout=15
  IdentityFile ~/.ssh/id_rsa

Host $VSI_HOST_1 $VSI_HOST_2 $VSI_HOST_3
  # ProxyJump $VSI_BASTION_HOST
  ProxyCommand ssh $VSI_BASTION_HOST -W %h:%p
EOF

chmod 400 ~/.ssh/config

for ((i = 1 ; i < $VPC_ZONE_COUNT + 1; i++ )); do 
  # Kills the running process, since the load balancer will no longer pass health check for that VSI it will not send traffic to it while it is not available. 
  # Note: WebSphere Libery does have a much better method for handling the health check, but this method is more portable to other environments/apps. 
  if [ "$i" = "1" ]; then
    scp target/liberty/wlp/usr/servers/defaultServer/sampleapp.zip root@$VSI_HOST_1:/
    ssh root@$VSI_HOST_1 "pkill java; sleep 10; cd /; rm -rf wlp; unzip -o sampleapp.zip; wlp/bin/server start"
    sleep 30
  elif [ "$i" = "2" ]; then
    sleep 60
    scp target/liberty/wlp/usr/servers/defaultServer/sampleapp.zip root@$VSI_HOST_2:/
    ssh root@$VSI_HOST_2 "pkill java; sleep 10; cd /; rm -rf wlp; unzip -o sampleapp.zip; wlp/bin/server start"
  elif [ "$i" = "3" ]; then
    sleep 60  
    scp target/liberty/wlp/usr/servers/defaultServer/sampleapp.zip root@$VSI_HOST_3:/
    ssh root@$VSI_HOST_3 "pkill java; sleep 10; cd /; rm -rf wlp; unzip -o sampleapp.zip; wlp/bin/server start"
  fi
done

# sleep for 90 seconds to allow enough time for the load balancer to recognize a server is available.
sleep 90

if [ "$(curl -sL -w "%{http_code}\\n" "http://${LB_HOSTNAME}/health" -o /dev/null --connect-timeout 5 --max-time 5 --retry 5 --retry-max-time 60)" = "200" ]; then
  display_access_urls
else
  echo "Could not reach health endpoint, although it is possible it is just a system delay.  Try again yourself using the information below."
  display_access_urls
  exit 1;
fi;