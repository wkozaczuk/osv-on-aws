#!/bin/bash
AWS_CLI="aws --profile best-dev"

VPC_ID=vpc-7d65b718
AMI=$1

SCRIPT_DIR=$(dirname $0)
source $SCRIPT_DIR/../env.sh

poll_instance_state() {
  $AWS_CLI ec2 describe-instances --instance-ids $1 > /tmp/describe-instances-$1.json
  instance_state=`jq -r .Reservations[0].Instances[0].State.Name /tmp/describe-instances-$1.json`
  log "The instance $1 is in state:${instance_state}"
}

poll_image_state() {
  $AWS_CLI ec2 describe-images --image-id $1 > /tmp/describe-images-$1.json
  image_state=`jq -r .Images[0].State /tmp/describe-images-$1.json`
  log "The image $1 is in state:${image_state}"
}

$AWS_CLI ec2 create-security-group --group-name OSv-bootstrap --description "OSv bootstrap security group" --vpc-id $VPC_ID > /tmp/create-security-group.json
security_group_id=`jq -r .GroupId /tmp/create-security-group.json`
$AWS_CLI ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 10000 --cidr 0.0.0.0/0
log "Created security group: $security_group_id"

log "Creating new instance from bootstrap AMI: $AMI"
$AWS_CLI ec2 run-instances --image-id $AMI --instance-type t2.nano --security-group-ids $security_group_id > /tmp/run-instances.json
instance_id=`jq -r .Instances[0].InstanceId /tmp/run-instances.json`
$AWS_CLI ec2 create-tags --resources $instance_id --tags "Key=Name,Value=OSv_bootstrap_instance"
log "Created new instance: $instance_id"

poll_instance_state $instance_id
while [ $instance_state != "running" ]; do 
  sleep 5
  poll_instance_state $instance_id
done
public_dns_name=`jq -r .Reservations[0].Instances[0].PublicDnsName /tmp/describe-instances-${instance_id}.json`
log "Instance $instance_id is running and reachable at [$public_dns_name]!!!"

$AWS_CLI ec2 get-console-output --instance-id $instance_id

###
### Use capstan to upload files
###

### Poll state until stopped
poll_instance_state $instance_id
while [ $instance_state != "stopped" ]; do 
  sleep 5
  poll_instance_state $instance_id
done

log "Creating image from instance ..."
$AWS_CLI ec2 create-image --instance-id $instance_id --name Smokowy_AMI > /tmp/create-image.json
new_image_id=`jq -r .ImageId /tmp/create-image.json`
log "Initiated creating new image $new_image_id from instance $instance_id"
poll_image_state $new_image_id
while [ $image_state != "available" ]; do
  sleep 5
  poll_image_state $new_image_id
done
log "Image $new_image_id is available"
