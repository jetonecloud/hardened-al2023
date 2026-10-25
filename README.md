# hardened-al2023

A Packer + Ansible pipeline that produces a **CIS Amazon Linux 2023 Level 1
-aligned** AMI: locked-down SSH, kernel/network sysctl hardening, auditd,
a default-deny host firewall, file integrity monitoring (AIDE), time sync
(chrony), and the SSM + CloudWatch agents, built from the latest official
AL2023 AMI and gated by an automated compliance test suite and a
vulnerability scan before anything gets published.

> **CIS-aligned, not CIS-certified.** This project implements controls
> inspired by and numbered against the CIS Amazon Linux 2023 Benchmark
> (Level 1 - Server). It has not been submitted to or certified by the
> Center for Internet Security, and no open-source template can make that
> claim on your behalf. See [docs/controls.md](docs/controls.md) for
> exactly what's implemented, what's skipped, and why.

## Repository layout

```
.
├── packer/                  Packer HCL2 build (source AMI, hardening,
│   ├── al2023.pkr.hcl         IMDSv2, encryption, provisioners)
│   ├── variables.pkr.hcl
│   ├── example.pkrvars.hcl
│   └── scripts/              Build-instance helper scripts (goss/trivy/cleanup)
├── ansible/                 Hardening roles, one per control group
│   ├── playbook.yml
│   └── roles/
│       ├── common/            baseline: patching, AIDE, chrony, SSM, banners,
│       │                      cron/sudo/password policy, file permissions
│       ├── ssh/                CIS 4.2.x - SSH server
│       ├── kernel/             CIS 1.1.1.x/1.1.8.x/1.1.9/1.5.x - kernel modules & sysctl
│       ├── network/            CIS 3.x - network sysctl + firewalld
│       ├── auditd/             CIS 5.2.x - audit rules
│       └── logging/            CIS 5.1.x/5.3 - rsyslog/journald/logrotate + CloudWatch Agent
├── tests/goss/               Compliance test profiles (one per role + advisory)
├── docs/                     Controls matrix, IAM policy, cost estimate, threat model
└── .github/workflows/        CI/CD: lint -> build -> test -> scan -> publish
```

## Quick start

Prerequisites: an AWS account, [Packer](https://developer.hashicorp.com/packer) >= 1.9,
[Ansible](https://docs.ansible.com/) >= 9, and AWS credentials with the
permissions in [docs/iam-policy.json](docs/iam-policy.json).

```bash
git clone https://github.com/jetonecloud/hardened-al2023.git
cd hardened-al2023

# Galaxy collections the roles depend on
ansible-galaxy collection install -r ansible/requirements.yml

# Fill in your VPC/subnet (or leave blank to use the account default)
cp packer/example.pkrvars.hcl packer/local.pkrvars.hcl
$EDITOR packer/local.pkrvars.hcl

cd packer
packer init al2023.pkr.hcl
packer validate -var-file=local.pkrvars.hcl al2023.pkr.hcl
packer build -var-file=local.pkrvars.hcl al2023.pkr.hcl
```

A successful build prints the new AMI ID and leaves machine-readable
reports in `reports/`: `manifest.json` (AMI ID/region/version),
`goss-results.json` + `goss-advisory-results.json` (compliance test
results), and `trivy-report.json` (vulnerability/secret/misconfig scan).
**The build fails outright if any control in the blocking Goss suites
fails** - see `packer/scripts/run-goss.sh`.

Or just use `make build` (see the `Makefile` for `fmt`, `validate`,
`lint`, `test`, and `scan` targets too).

## What gets hardened

Each Ansible role owns one control area and every task is tagged with the
CIS control ID(s) it implements, e.g. `CIS 4.2.10 | Ensure SSH root login
disabled`. Highlights:

- **ssh** - key-only auth, no root login, modern ciphers/MACs/KEX only,
  idle-session reaping, config validated with `sshd -t` before it's ever
  applied (so a typo can't lock out the build or any host that runs this
  playbook).
- **kernel** - unused filesystem/USB-storage kernel modules blocked, ASLR,
  restricted ptrace, core dumps disabled, `/dev/shm` mounted
  `noexec,nodev,nosuid`.
- **network** - uncommon protocol modules blocked, a full sysctl hardening
  set (no source routing, no ICMP redirects, SYN cookies, reverse-path
  filtering, martian logging), and firewalld in a default-deny `drop` zone
  with SSH explicitly allowed.
- **auditd** - a comprehensive rules.d ruleset (identity, time, MAC policy,
  logins/sessions, permission changes, unauthorized access, mounts,
  deletions, module loading, sudoers, and privileged-command use generated
  from a live setuid/setgid scan), locked immutable (`-e 2`) each boot.
- **logging** - rsyslog/journald hardening, bounded log rotation, and the
  CloudWatch Agent shipping key logs and host metrics off-box.
- **common** - AIDE file integrity monitoring, chrony against the Amazon
  Time Sync Service, the SSM Agent, password/umask/account-aging policy,
  sudo hardening, warning banners, non-legacy crypto policy, and removal of
  any special-purpose service/client packages.

Plus, enforced directly in the Packer template (not optional, not a
variable you can accidentally leave off): **IMDSv2 required**, an
**encrypted root volume**, and **no hardcoded users, passwords, or SSH
keys** - Packer generates a fresh ephemeral keypair per build and discards
it when the build ends.

### Control matrix

Status legend: **Implemented**, **Partial** (OS default, verified not
configured), **Advisory** (checked, never auto-remediated), **Skipped**
(deliberate, reason given), **N/A** (doesn't apply to this platform). The
full version with extra detail lives in
[docs/controls.md](docs/controls.md).

#### 1. Initial Setup

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 1.1.1.1-1.1.1.6 | Disable cramfs/freevxfs/jffs2/hfs/hfsplus/udf modules | Implemented | |
| 1.1.1.7 | Disable vfat module | **Skipped** | EC2 UEFI boot needs vfat for `/boot/efi`; blacklisting risks an unbootable AMI |
| 1.1.2.x-1.1.7.x | Separate partitions for `/tmp`,`/var`,`/var/tmp`,`/var/log`,`/var/log/audit`,`/home` | **Skipped** | Single root EBS volume; add via LVM/extra volumes downstream if required |
| 1.1.8.x | `/dev/shm` `nodev,nosuid,noexec` | Implemented | |
| 1.1.9 | Disable USB storage | Implemented | Defensive; Nitro has no USB bus |
| 1.2.1 | Patch at build time | Implemented | |
| 1.2.2-1.2.4 | `dnf-automatic` | **Skipped (opt-in)** | Golden-AMI model patches by rebuild, not live mutation - see Threat model |
| 1.3.1-1.3.3 | AIDE install/init/schedule/permission checks | Implemented | |
| 1.4.1 | Bootloader password | **Skipped** | Not EC2's threat model; risks breaking console recovery |
| 1.5.1 | ASLR | Implemented | |
| 1.5.2 | NX/DEP | Partial | Hardware default on AWS x86_64/arm64 |
| 1.5.3 | ptrace_scope | Implemented | |
| 1.5.4 | Unprivileged user namespaces | **Skipped** | Breaks container runtimes; Level 2 scope upstream |
| 1.6.1.x | SELinux enforcing | **Skipped** | Blind fleet-wide enforcement risks breaking workloads unpredictably; reported via advisory check |
| 1.7.1-1.7.3, 1.7.5 | Login/MOTD banners | Implemented | |
| 1.7.4, 1.7.6 | Banner wording "authorized" | **Skipped** | Legal/org review, not a technical control |
| 1.8 | GDM banner | N/A | Headless AMI |
| 1.9 | Crypto policy not LEGACY | Implemented | |

#### 2. Services

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 2.1.1-2.1.2 | Time sync (chrony) | Implemented | Amazon Time Sync Service |
| 2.2.1-2.2.18 | Remove special-purpose server packages | Implemented | None ship by default; drift protection |
| 2.3.1-2.3.3 | Remove client packages (telnet/LDAP/FTP) | Implemented | |
| 2.4 | Remove squid | Implemented | |

#### 3. Network

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 3.1.1-3.1.4 | Disable DCCP/SCTP/RDS/TIPC modules | Implemented | |
| 3.1.5 | Disable IPv6 | **Skipped by default (opt-in)** | Many VPCs are dual-stack; `network_disable_ipv6` |
| 3.2.x/3.3.x | Source routing, redirects, forwarding, martians, SYN cookies, rp_filter | Implemented | |
| 3.3.9 | IPv6 router advertisements rejected | Implemented | Applies regardless of the IPv6 toggle |
| 3.4.1.x/3.4.2.x | Default-deny host firewall | Implemented | firewalld `drop` zone, SSH allowed; manages nftables directly |

#### 4. Access, Authentication and Authorization

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 4.1.1-4.1.9 | cron/at enabled, permissioned, restricted | Implemented | |
| 4.2.1-4.2.20 | SSH hardening (full set) | Implemented | |
| 4.3.1-4.3.6 | sudo/`su` hardening | Implemented | |
| 4.4.1-4.4.2 | authselect custom profile + faillock | **Skipped** | High lockout blast radius fleet-wide; deliberate extension point |
| 4.5.1 | Password quality (`pwquality.conf`) | Implemented | |
| 4.5.2 | Account lockout (faillock) | **Skipped** | Depends on 4.4.x; reported via advisory check |
| 4.5.3 | SHA-512 hashing | Implemented | |
| 4.5.4 | Password reuse prevention | **Skipped** | Same authselect dependency |
| 4.6.1.1-4.6.1.4 | Password aging, inactive lock | Implemented | |
| 4.6.1.5 | No future password changes | N/A / Verified | Audit-only, trivial on a fresh image |
| 4.6.2 | System accounts non-interactive | Implemented | |
| 4.6.3-4.6.6 | Idle shell timeout, umask `027` | Implemented | |

#### 5. Logging and Auditing

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 5.1.1.1-5.1.1.5, 5.1.1.7 | rsyslog installed/enabled/permissioned | Implemented | |
| 5.1.1.6 | Remote rsyslog target | **Skipped** | Superseded by CloudWatch Logs |
| 5.1.2.1.x | `systemd-journal-remote` | **Skipped** | Superseded by CloudWatch Logs |
| 5.1.2.2-5.1.2.6 | journald persistence, compression, forwarding, size cap | Implemented | |
| 5.1.2.7 | journald time sync | Implemented | via chrony |
| 5.1.3 | journalctl access control | Partial | systemd default, not re-hardened |
| 5.2.1.1-5.2.1.2 | auditd installed/enabled | Implemented | |
| 5.2.1.3 | `audit_backlog_limit` (GRUB) | **Skipped** | Needs a cmdline change + reboot mid-build |
| 5.2.1.4, 5.2.2.x | Audit storage/retention/disk-full behavior | Implemented | `admin_space_left_action=halt` by default - see Threat model |
| 5.2.3.x/5.2.4.x | Full audit rules.d ruleset | Implemented | Privileged-command rules generated from a live scan |
| 5.3 | Log rotation | Implemented | |

#### 6. System Maintenance

| ID | Control | Status | Notes |
|----|---------|--------|-------|
| 6.1.1-6.1.8 | Identity file ownership/permissions | Implemented | |
| 6.1.9-6.1.12 | No world-writable/unowned/ungrouped/SGID files anywhere | **Advisory** | Blind fleet-wide remediation risks breaking things; reported, not auto-fixed |
| 6.2.1 | Shadowed passwords | Implemented | AL2023 default, verified |
| 6.2.2-6.2.4 | System accounts secured, root GID 0 | Implemented | |
| 6.2.5 | Default umask | Implemented | Same as 4.6.6 |
| 6.2.6 | Login retries limited | **Skipped** | Depends on faillock |
| 6.2.7-6.2.11 | Home directory/dotfile hygiene | Not implemented | No extra interactive users on a fresh image; downstream provisioning concern |

#### Beyond CIS

| Requirement | Status |
|---|---|
| IMDSv2 required | Implemented (unconditionally, in the Packer source block) |
| Encrypted root volume | Implemented (unconditionally) |
| No hardcoded users/keys | Implemented (ephemeral build keypair, key-only SSH, no static accounts) |
| SSM Agent / CloudWatch Agent / chrony / AIDE preinstalled + enabled | Implemented |

## Testing

[Goss](https://github.com/goss-org/goss) profiles in `tests/goss/` are
uploaded to the build instance and run **before** the AMI is created:
`goss.yaml` plus one profile per role (`goss_ssh.yaml`, `goss_kernel.yaml`,
`goss_network.yaml`, `goss_auditd.yaml`, `goss_logging.yaml`) are blocking -
any failure fails the Packer build. `goss_advisory.yaml` covers controls
this project deliberately doesn't auto-remediate (world-writable file
scans, SELinux enforcing status, faillock presence) and is informational
only.

To run the suite by hand against a live host:

```bash
scp -r tests/goss ec2-user@<host>:/tmp/goss
ssh ec2-user@<host> 'sudo GOSS_FILES_PATH=/tmp/goss goss -g /tmp/goss/goss_ssh.yaml validate'
```

## Scanning

[Trivy](https://github.com/aquasecurity/trivy) runs a filesystem scan
(`vuln`, `secret`, `misconfig`) on the build instance right before cleanup
and produces `reports/trivy-report.json`. By default this doesn't fail the
Packer build itself (`trivy_fail_on_critical=false` - OS package CVEs can
lag a day or two independent of anything this project controls), but the
CI pipeline's `scan` job parses the report and **fails the pipeline on any
CRITICAL vulnerability or exposed secret** before the `publish` job runs.

## CI/CD pipeline

`.github/workflows/pipeline.yml` runs on push/PR to `main`, a weekly
schedule (patch-by-rebuild), tag pushes, and manual dispatch:

1. **lint** - `packer fmt -check`, `packer validate`, `ansible-lint`, `yamllint`
2. **build** - authenticates to AWS via OIDC (no static keys), runs
   `packer build`, uploads `goss-results.json`, `goss-advisory-results.json`,
   `trivy-report.json`, and `manifest.json` as a workflow artifact
3. **test** - fails the pipeline if any blocking Goss suite has a failure
4. **scan** - fails the pipeline on CRITICAL Trivy findings or secrets
5. **publish** - points an SSM parameter (`/hardened-al2023/<region>/latest`)
   at the new AMI and, on a `vX.Y.Z` tag push, cuts a GitHub Release with
   the reports attached

`build`/`test`/`scan`/`publish` are skipped on pull requests (lint-only
feedback there) so AMIs aren't built on every PR.

### Required GitHub repository configuration

Set these as repository (or environment) **variables**, not secrets - none
of them are sensitive:

| Variable | Purpose |
|---|---|
| `AWS_ROLE_ARN` | OIDC role the pipeline assumes (see IAM policy below) |
| `AWS_REGION` | Build region (default `us-east-1`) |
| `PACKER_VPC_ID` / `PACKER_SUBNET_ID` | Network to launch the build instance in |
| `PACKER_KMS_KEY_ID` | Optional CMK for root volume encryption |

### OIDC trust policy

The role at `AWS_ROLE_ARN` needs a trust policy scoped to this repo (adjust
the `sub` condition to your fork/branch rules):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:jetonecloud/hardened-al2023:*"
        }
      }
    }
  ]
}
```

## Required IAM policy

Two separate roles are involved - don't conflate them:

1. **The pipeline/OIDC role** (`AWS_ROLE_ARN` above) - what GitHub Actions
   assumes to run Packer. Full policy at
   [docs/iam-policy.json](docs/iam-policy.json): EC2 build/image
   permissions, read access to the public AL2023 SSM parameter, write
   access to this project's own `/hardened-al2023/*` SSM namespace, KMS
   grant/encrypt permissions for root volume encryption, and `iam:PassRole`
   scoped to the build instance profile below.
2. **The build/runtime instance profile** (`hardened-al2023-build-instance-profile`
   in the policy above) - attached to the EC2 instance itself, both during
   the build and for any instance you later launch from the AMI. Needs AWS
   managed policies `AmazonSSMManagedInstanceCore` (SSM Agent) and
   `CloudWatchAgentServerPolicy` (CloudWatch Agent).

## Cost estimate

A single build costs well under $0.05 in AWS spend (a few minutes of
`t3.micro` + a transient 10 GiB volume). The ongoing cost is **AMI
snapshot storage** - roughly $0.80/GiB-month per AMI version you keep, and
the pipeline's weekly schedule will produce a new version every week if
left running, so set a retention/pruning policy. Full breakdown, including
expected run-time CloudWatch Logs/metrics cost, in
[docs/cost-estimate.md](docs/cost-estimate.md).

## Threat model note

This hardens the OS image and the pipeline that builds it: SSH/network
exposure, privilege escalation after a foothold, audit evidence for
after-the-fact investigation, and build-pipeline integrity (OIDC,
automated test/scan gates, config validated before it's applied). It does
**not** cover your application's security, your VPC/Security Group design,
upstream AL2023 package supply chain, or compliance certification. One
tradeoff worth knowing up front: `admin_space_left_action` defaults to
`halt` - a full audit partition will take an instance down by design,
trading availability for audit-trail integrity. Full note in
[docs/threat-model.md](docs/threat-model.md).

## Contributing, security, license

- Found a bug or want to add a control? See [CONTRIBUTING.md](CONTRIBUTING.md).
- Found a security issue? See [SECURITY.md](SECURITY.md) - please don't
  open a public issue for it.
- Licensed under [Apache 2.0](LICENSE).
- See [CHANGELOG.md](CHANGELOG.md) for release history.
