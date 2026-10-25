## -----------------------------------------------------------------------
## Input variables for the hardened-al2023 Packer build.
##
## None of these carry secrets or hardcoded credentials/keys. Anything
## environment-specific (VPC, subnet, KMS key) is left empty by default
## and must be supplied via a *.pkrvars.hcl file or -var on the CLI.
## See packer/example.pkrvars.hcl for a starting point.
## -----------------------------------------------------------------------

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to build the AMI in."
}

variable "source_ami_ssm_parameter" {
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  description = <<-EOT
    Public SSM parameter that always resolves to the latest official AL2023
    AMI ID for the chosen architecture. Using SSM instead of a pinned AMI ID
    means every build starts from the current AL2023 release.
  EOT
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type used for the temporary build/test instance. Not the type end users run."
}

variable "ssh_username" {
  type        = string
  default     = "ec2-user"
  description = "Default login user baked into AL2023. Used only to connect Packer's ephemeral, auto-generated SSH keypair during the build."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC to launch the build instance in. Empty lets Packer pick the account's default VPC."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Subnet to launch the build instance in. Must have a route to the internet (via IGW or NAT) or VPC endpoints for SSM, S3 and EC2."
}

variable "associate_public_ip_address" {
  type        = bool
  default     = true
  description = "Whether the build instance gets a public IP. Set false when building from a private subnet with SSM/S3 VPC endpoints."
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Extra security group IDs to attach to the build instance. Packer always also opens a temporary SG for its own SSH access, removed at the end of the build."
}

variable "subnet_filter_default_for_az" {
  type        = bool
  default     = true
  description = "If subnet_id is empty, let Packer pick a default subnet in the default VPC for the build instance."
}

variable "root_volume_size_gb" {
  type        = number
  default     = 10
  description = "Root EBS volume size, in GiB, for both the build instance and the resulting AMI."
}

variable "root_volume_type" {
  type        = string
  default     = "gp3"
  description = "Root EBS volume type."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = <<-EOT
    Optional customer-managed KMS key (ARN or ID) used to encrypt the AMI's
    root volume. The root volume is ALWAYS encrypted (see encrypt_boot in
    al2023.pkr.hcl); leaving this empty uses the AWS-managed aws/ebs key.
  EOT
}

variable "ami_name_prefix" {
  type        = string
  default     = "hardened-al2023"
  description = "Prefix for the resulting AMI name. The full name also includes the build version and a timestamp for uniqueness."
}

variable "build_version" {
  type        = string
  default     = "dev"
  description = "Version tag applied to the AMI (e.g. a semver git tag like 1.2.0, or 'dev' for local builds). Set by CI from the git ref."
}

variable "ami_users" {
  type        = list(string)
  default     = []
  description = "AWS account IDs to share the built AMI with. Empty keeps the AMI private to the building account."
}

variable "ami_regions" {
  type        = list(string)
  default     = []
  description = "Additional regions to copy the finished AMI into."
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every taggable resource (AMI, snapshot, build instance)."
}

variable "goss_version" {
  type        = string
  default     = "v0.4.9"
  description = "Pinned goss release used to run the compliance test suite on the build instance."
}

variable "trivy_version" {
  type        = string
  default     = "0.56.2"
  description = "Pinned trivy release used for the post-build filesystem/vulnerability scan."
}

variable "trivy_severity" {
  type        = string
  default     = "CRITICAL,HIGH"
  description = "Comma-separated severities trivy reports on."
}

variable "trivy_fail_on_critical" {
  type        = bool
  default     = false
  description = <<-EOT
    If true, the build fails when trivy finds any CRITICAL vulnerability in
    the image filesystem. Default false: OS-package CVEs are reported as an
    artifact for the pipeline's scan stage to gate on, rather than blocking
    the image build itself (upstream AL2023 packages may lag a CVE fix by a
    few days independent of anything this project controls).
  EOT
}
