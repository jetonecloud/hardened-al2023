## -----------------------------------------------------------------------
## hardened-al2023: Packer build definition
##
## Produces a CIS Amazon Linux 2023 Level 1 -aligned AMI:
##   1. Resolve the latest official AL2023 AMI via a public SSM parameter.
##   2. Launch a short-lived build instance with IMDSv2 enforced and an
##      encrypted root volume.
##   3. Apply the Ansible hardening roles over SSH (Packer's own ephemeral,
##      auto-generated keypair -- no keys are stored in this repo).
##   4. Run the Goss compliance suite; a critical failure aborts the build.
##   5. Run a Trivy filesystem/vulnerability scan and save the report.
##   6. Clean the instance and bake the AMI.
## -----------------------------------------------------------------------

packer {
  required_version = ">= 1.9.0"

  required_plugins {
    amazon = {
      version = ">= 1.3.1"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

## Always resolves to the current, patched AL2023 AMI -- never a pinned,
## potentially stale AMI ID.
data "amazon-parameterstore" "al2023" {
  name   = var.source_ami_ssm_parameter
  region = var.aws_region
}

locals {
  build_timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
  ami_name        = "${var.ami_name_prefix}-${var.build_version}-${local.build_timestamp}"

  common_tags = merge(
    {
      Name         = local.ami_name
      Project      = "hardened-al2023"
      ManagedBy    = "packer"
      BuildVersion = var.build_version
      BaseAmi      = data.amazon-parameterstore.al2023.value
      CISAlignment = "CIS Amazon Linux 2023 Level 1 (aligned, not certified)"
      BuiltAt      = local.build_timestamp
    },
    var.extra_tags
  )
}

source "amazon-ebs" "al2023" {
  region        = var.aws_region
  source_ami    = data.amazon-parameterstore.al2023.value
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  # No static SSH key is ever written to disk or committed: Packer
  # generates a fresh ephemeral keypair per build and discards it on exit.
  temporary_key_pair_type = "ed25519"

  ami_name        = local.ami_name
  ami_description = "Hardened AL2023 (CIS Level 1 -aligned) built ${local.build_timestamp} from ${data.amazon-parameterstore.al2023.value}"

  vpc_id                      = var.vpc_id != "" ? var.vpc_id : null
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = var.associate_public_ip_address
  security_group_ids          = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  ami_users   = var.ami_users
  ami_regions = var.ami_regions

  # --- Required: IMDSv2 only, hop limit 2 (allows containerized workloads
  # on the running instance to still reach the metadata service through
  # one extra network hop, e.g. a Docker bridge). ---
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # --- Required: encrypted root volume. AL2023's published AMIs use
  # /dev/xvda as the root device for both x86_64 and arm64; if you build
  # from a different source AMI, update this device name. ---
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = var.root_volume_size_gb
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null
  }

  tags            = local.common_tags
  run_tags        = local.common_tags
  run_volume_tags = local.common_tags
  snapshot_tags   = local.common_tags

  # Disable the instance's public-facing shutdown behavior quirks and make
  # sure terminated build instances don't linger.
  shutdown_behavior = "terminate"

  communicator = "ssh"
}

build {
  name    = "hardened-al2023"
  sources = ["source.amazon-ebs.al2023"]

  # Local-only: prepare a place to receive report artifacts from the
  # instance. Runs on the Packer host, not the remote build instance.
  provisioner "shell-local" {
    inline = ["mkdir -p ../reports"]
  }

  provisioner "shell" {
    script = "scripts/bootstrap.sh"
  }

  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
    user          = var.ssh_username
    use_proxy     = false
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_CONFIG=../ansible/ansible.cfg",
    ]
  }

  # ---- Compliance test stage (Goss) ----
  provisioner "file" {
    source      = "../tests/goss/"
    destination = "/tmp/goss"
  }

  provisioner "shell" {
    script = "scripts/install-goss.sh"
    environment_vars = [
      "GOSS_VERSION=${var.goss_version}",
    ]
  }

  provisioner "shell" {
    # Non-zero exit here fails the Packer build outright: critical
    # control failures must never produce a published AMI.
    script = "scripts/run-goss.sh"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss-results.json"
    destination = "../reports/goss-results.json"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss-advisory-results.json"
    destination = "../reports/goss-advisory-results.json"
  }

  # ---- Scan stage (Trivy) ----
  provisioner "shell" {
    script = "scripts/install-trivy.sh"
    environment_vars = [
      "TRIVY_VERSION=${var.trivy_version}",
    ]
  }

  provisioner "shell" {
    script = "scripts/run-trivy.sh"
    environment_vars = [
      "TRIVY_SEVERITY=${var.trivy_severity}",
      "TRIVY_FAIL_ON_CRITICAL=${var.trivy_fail_on_critical}",
    ]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/trivy-report.json"
    destination = "../reports/trivy-report.json"
  }

  # ---- Bake hygiene ----
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }

  post-processor "manifest" {
    output     = "../reports/manifest.json"
    strip_path = true
    custom_data = {
      build_version = var.build_version
      source_ami    = data.amazon-parameterstore.al2023.value
    }
  }
}
