## Copy this file to local.pkrvars.hcl (git-ignored) and fill in values for
## your account, or pass equivalent -var flags / environment-specific CI
## variables. Nothing in this example file is a real credential or key.

aws_region    = "us-east-1"
instance_type = "t3.micro"

# Leave empty to use the account's default VPC/subnet.
vpc_id    = ""
subnet_id = ""

associate_public_ip_address = true

root_volume_size_gb = 10
root_volume_type    = "gp3"

# Optional customer-managed KMS key ARN/ID for AMI encryption.
# Leave empty to use the AWS-managed aws/ebs key.
kms_key_id = ""

ami_name_prefix = "hardened-al2023"
build_version   = "dev"

# Share the AMI with other accounts, or leave empty to keep it private.
ami_users   = []
ami_regions = []

extra_tags = {
  Environment = "dev"
  Owner       = "replace-me"
}
