#!/bin/bash
AWS_CLI="aws --profile personal"

IMAGE_PATH=$1
S3_BUCKET_NAME=wkozaczuk-osv-images
IMAGE_NAME=$2

SCRIPT_DIR=$(dirname $0)
source $SCRIPT_DIR/env.sh

poll_import_snapshot_task() {
  $AWS_CLI ec2 describe-import-snapshot-tasks --import-task-ids $1 > /tmp/describe-import-snapshot-tasks.json
  task_status=`jq -r .ImportSnapshotTasks[].SnapshotTaskDetail.Status /tmp/describe-import-snapshot-tasks.json`
  local task_progress=`jq -r .ImportSnapshotTasks[].SnapshotTaskDetail.Progress /tmp/describe-import-snapshot-tasks.json`
  local task_status_message=`jq -r .ImportSnapshotTasks[].SnapshotTaskDetail.StatusMessage /tmp/describe-import-snapshot-tasks.json`
  log "Status of import snapshot task: [$task_status,$task_status_message,$task_progress]"
}

poll_ami_state() {
  $AWS_CLI ec2 describe-images --image-ids $1 > /tmp/describe-images.json
  image_state=`jq -r .Images[].State /tmp/describe-images.json`
  log "State of the image: $image_state"
}

### Copy the raw image to S3
log "Copying $IMAGE_PATH to s3://${S3_BUCKET_NAME}/${IMAGE_NAME} ..."
$AWS_CLI s3 cp $IMAGE_PATH s3://${S3_BUCKET_NAME}/${IMAGE_NAME}
log "Completed copying $IMAGE_PATH to S3"

### Import the image in S3 as a snapshot
CONTAINER_JSON=/tmp/${IMAGE_NAME}_snapshot_container.json 
cat << EOF > $CONTAINER_JSON
{
  "Description": "${IMAGE_NAME}",
  "Format": "raw",
  "UserBucket": {
    "S3Bucket": "${S3_BUCKET_NAME}",
    "S3Key": "${IMAGE_NAME}"
  }
}
EOF

log "Importing s3://${S3_BUCKET_NAME}/${IMAGE_NAME} as a snapshot"
$AWS_CLI ec2 import-snapshot --description "$IMAGE_NAME" --disk-container file://$CONTAINER_JSON > /tmp/import-snapshot.json
snapshot_task_id=`jq -r .ImportTaskId /tmp/import-snapshot.json`
log "Import snapshot task ID: $snapshot_task_id"

poll_import_snapshot_task $snapshot_task_id
while [ $task_status != "completed" ]; do
  sleep 5
  poll_import_snapshot_task $snapshot_task_id
done

snapshot_id=`jq -r .ImportSnapshotTasks[].SnapshotTaskDetail.SnapshotId /tmp/describe-import-snapshot-tasks.json`
log "Completed importing snapshot ID: $snapshot_id"

### Register snapshot as AMI
log "Registering snapshot ID: $snapshot_id as AMI"
$AWS_CLI ec2 register-image --name "$IMAGE_NAME" --architecture x86_64 --root-device-name xvda --virtualization-type hvm --block-device-mappings "[{\"DeviceName\": \"xvda\",\"Ebs\":{\"DeleteOnTermination\":true,\"SnapshotId\":\"$snapshot_id\"}}]" > /tmp/register-image.json

ami=`jq -r .ImageId /tmp/register-image.json`
log "Registered AMI: $ami"

poll_ami_state $ami
while [ $image_state != "available" ]; do
  sleep 5
  poll_ami_state $ami
done
log "Completed registering AMI: $ami"

#DELETE snapshot - maybe
