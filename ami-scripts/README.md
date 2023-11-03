These two scripts can be used to create AMI images intended to run OSv guest on EC2 instances:

* `create_ami_from_image.sh` - creates an AMI from an OSv image under `$OSV_ROOT/build/release/usr.img` or local Capstan images located under `~/.capstan/repository`; the `usr.img` needs to be converted to the raw image using the command `qemu-img convert -f qcow2 -O raw usr.img usr.raw` and then `usr.raw` can be used as an input to this script
* `create_ami_from_ami.sh` - creates new AMI by 'snapshot'-ting a running EC2 instance OSv on it; intended to be used with Capstan command `capstan package compose-remote`  
