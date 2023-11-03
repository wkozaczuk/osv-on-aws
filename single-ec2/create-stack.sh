aws --profile personal cloudformation create-stack \
 --stack-name golang-pie-htttpserver-fixed \
 --template-body file:///home/wkozaczuk/projects/osv-aws-templates/single-ec2/single-instance.yaml \
 --parameters file:///home/wkozaczuk/projects/osv-aws-templates/single-ec2/single-instance-parameters.json \
 --capabilities CAPABILITY_IAM
