# Control matrix

This matrix maps every control group in the CIS Amazon Linux 2023 Benchmark
(Level 1 - Server) to how this project handles it. Control IDs follow the
numbering used by the upstream RHEL-family CIS benchmarks that the AL2023
benchmark is modeled on; treat them as an **alignment aid**, not a verbatim
reproduction of CIS's copyrighted control text.

**This project is CIS-aligned. It is not CIS-certified, and nobody should
represent it as such.** No automated open-source tool can certify compliance
on your behalf - certification is an attestation process against your
specific environment, done by/with CIS or an authorized assessor.

Status legend: **Implemented** (enforced by a role), **Partial** (enforced
by an OS default this project verifies but does not independently
configure), **Advisory** (checked and reported by the Goss advisory suite,
never auto-remediated), **Skipped** (deliberately not done - reason given),
**N/A** (doesn't apply to this platform).

## 1. Initial Setup

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 1.1.1.1-1.1.1.6 | Disable cramfs/freevxfs/jffs2/hfs/hfsplus/udf kernel modules | Implemented | `kernel` role | modprobe.d blacklist + `install .../bin/false` |
| 1.1.1.7 | Disable vfat kernel module | **Skipped** | - | EC2 instances that boot via UEFI mount `/boot/efi` as vfat; blacklisting the module risks an unbootable AMI. Upstream RHEL8/9 CIS benchmarks also exclude vfat from this list for the same reason. |
| 1.1.2.x-1.1.7.x | Separate partitions + `nodev/nosuid/noexec` for `/tmp`, `/var`, `/var/tmp`, `/var/log`, `/var/log/audit`, `/home` | **Skipped** | - | The AMI ships a single root EBS volume. Partition separation is a storage-layout decision made at instance/volume provisioning time, not AMI build time. If your organization requires this, add the partitions via LVM or extra EBS volumes + `/etc/fstab` entries downstream (a good role to contribute - see CONTRIBUTING.md). |
| 1.1.8.1-1.1.8.4 | `/dev/shm` mounted `nodev,nosuid,noexec` | Implemented | `kernel` role | tmpfs remount + persistent fstab entry |
| 1.1.9 | Disable USB storage | Implemented | `kernel` role | Defensive; Nitro instances have no USB bus, but costs nothing to block the driver |
| 1.2.1 | Keep packages patched | Implemented | `common` role | Full `dnf update` at build time |
| 1.2.2-1.2.4 | `dnf-automatic` scheduled/security updates | **Skipped (opt-in)** | `common` role, `common_enable_dnf_automatic` | This is an immutable-AMI pipeline: you patch by rebuilding and replacing instances (the pipeline rebuilds weekly), not by mutating running ones. Flip the variable on if your fleet instead relies on in-place patching. |
| 1.3.1-1.3.2 | AIDE installed, initialized, and checked on a schedule | Implemented | `common` role | Daily cron; `/usr/sbin/aide --check` |
| 1.3.3 | AIDE checks permissions/ownership | Implemented | `common` role | `NORMAL` ruleset includes `p+u+g` |
| 1.4.1 | Bootloader password | **Skipped** | - | EC2 instances don't have the console-access threat model a bootloader password defends against, and a wrong GRUB password can brick serial-console recovery. |
| 1.5.1 | ASLR enabled | Implemented | `kernel` role | `kernel.randomize_va_space=2` |
| 1.5.2 | NX/DEP enabled | Partial | - | Hardware/kernel default on all AWS x86_64/arm64 instance types; not sysctl-configurable. Verified, not configured. |
| 1.5.3 | Restrict ptrace scope | Implemented | `kernel` role | `kernel.yama.ptrace_scope=1` |
| 1.5.4 | Restrict unprivileged user namespaces | **Skipped** | - | Breaks container runtimes (Docker, rootless containers, most CNI setups) that this AMI may well be used to run. Upstream benchmarks typically gate this at Level 2 for the same compatibility reason; out of scope for this project's Level 1 target. |
| 1.6.1.1-1.6.1.8 | SELinux installed, enforcing, policy hardened | **Skipped** | - | Flipping SELinux to `enforcing` blind, fleet-wide, risks breaking an unknown set of downstream workloads unpredictably. `getenforce` is checked (and reported) by the Goss advisory suite; enable enforcing mode yourself after testing against your actual workload. |
| 1.7.1-1.7.3, 1.7.5 | Local/remote/MOTD login banners | Implemented | `common` role | `/etc/issue`, `/etc/issue.net`, `/etc/motd` |
| 1.7.4, 1.7.6 | Banner wording "authorized" by the organization | **Skipped** | - | This is a legal/organizational sign-off on banner text, not a technical control. Review and edit `ansible/roles/common/templates/banner.j2` to match your counsel's wording. |
| 1.8 | GDM login banner | N/A | - | Headless AMI; no graphical login manager is installed. |
| 1.9 | System-wide crypto policy not LEGACY | Implemented | `common` role | `update-crypto-policies --set DEFAULT` |

## 2. Services

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 2.1.1-2.1.2 | Time sync installed and configured | Implemented | `common` role | chrony against Amazon Time Sync Service (`169.254.169.123`) |
| 2.2.1-2.2.18 | Remove special-purpose server packages (avahi, CUPS, DHCP server, DNS, dnsmasq, vsftpd, TFTP, httpd, nginx, mail/IMAP, net-snmp, telnet-server, Samba, NFS, rpcbind, rsync daemon) | Implemented | `common` role | None ship on the stock AL2023 AMI; this guards against drift in a customized base image |
| 2.3.1-2.3.3 | Remove client packages (telnet, LDAP, FTP) | Implemented | `common` role | |
| 2.4 | Remove squid | Implemented | `common` role | |

## 3. Network

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 3.1.1-3.1.4 | Disable DCCP/SCTP/RDS/TIPC kernel modules | Implemented | `network` role | |
| 3.1.5, 3.3.9 | Disable IPv6 / router advertisements | Implemented (RA) / **Skipped by default** (full disable) | `network` role, `network_disable_ipv6` | Many VPCs run dual-stack or IPv6-only subnets; disabling IPv6 fleet-wide by default could cut off connectivity, including to SSM. RA is still rejected (`accept_ra=0`) regardless. |
| 3.2.1-3.2.2, 3.3.1-3.3.8 | Source routing, ICMP redirects, IP forwarding, martian logging, broadcast/bogus ICMP, reverse-path filtering, SYN cookies | Implemented | `network` role | sysctl drop-in |
| 3.4.1.1-3.4.2.7 | Host firewall installed, default-deny, loopback/established allowed | Implemented | `network` role | firewalld, default zone `drop`, SSH explicitly allowed. AL2023's firewalld manages the nftables backend directly, so raw nftables table/chain controls are satisfied through firewalld rather than hand-written nftables rules. |

## 4. Access, Authentication and Authorization

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 4.1.1-4.1.9 | cron/at enabled, permissioned, and restricted to root | Implemented | `common` role | |
| 4.2.1-4.2.20 | SSH server: no root login, key-only auth, strong ciphers/MACs/KEX, idle timeouts, banner, logging, no forwarding | Implemented | `ssh` role | Validated with `sshd -t` before being applied |
| 4.3.1-4.3.6 | sudo hardening (pty, logfile, timeout, secure_path), `su` restricted to `wheel` | Implemented | `common` role | |
| 4.4.1-4.4.2 | Custom authselect profile with faillock | **Skipped** | - | Requires regenerating the authselect-managed PAM stack. A mistake here can lock out *all* authentication fleet-wide on every AMI built from this project - too high a blast radius to guess at in a generic OSS role. Left as a deliberate, documented extension point (see CONTRIBUTING.md). |
| 4.5.1 | Password quality requirements (`pwquality.conf`) | Implemented | `common` role | Doesn't need authselect - read directly by `pam_pwquality.so` |
| 4.5.2 | Account lockout (faillock) | **Skipped** | - | Depends on 4.4.1-4.4.2. Checked (not enforced) by the Goss advisory suite. |
| 4.5.3 | SHA-512 password hashing | Implemented | `common` role | `ENCRYPT_METHOD SHA512` in `login.defs` |
| 4.5.4 | Password reuse prevention (pwhistory) | **Skipped** | - | Same authselect dependency as 4.4.x. |
| 4.6.1.1-4.6.1.4 | Password aging and inactive-account lock | Implemented | `common` role | `login.defs` + `/etc/default/useradd` |
| 4.6.1.5 | No existing user's last password change is in the future | N/A / Verified | - | Audit-only; trivially true on a freshly built image. |
| 4.6.2 | System accounts are non-interactive | Implemented | `common` role | Shell swapped to `/sbin/nologin` for system UIDs with a login shell |
| 4.6.3-4.6.4 | Idle shell timeout (`TMOUT`) | Implemented | `common` role | 900s, read-only, exported |
| 4.6.5-4.6.6 | Default umask `027` | Implemented | `common` role | `login.defs` + `/etc/profile.d` |

## 5. Logging and Auditing

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 5.1.1.1-5.1.1.5, 5.1.1.7 | rsyslog installed, enabled, permissioned, not accepting remote logs | Implemented | `logging` role | |
| 5.1.1.6 | rsyslog ships to a remote syslog server | **Skipped** | - | Superseded by the CloudWatch Logs agent (see below) rather than standing up a second, self-managed log-shipping path. |
| 5.1.2.1.1-5.1.2.1.4 | `systemd-journal-remote` | **Skipped** | - | Same reason: superseded by CloudWatch Logs. |
| 5.1.2.2-5.1.2.6 | journald persistent storage, compression, syslog forwarding, size cap | Implemented | `logging` role | |
| 5.1.2.7 | journald time sync | Implemented | `common` role | via chrony |
| 5.1.3 | journalctl access control | Partial | - | Relies on the systemd default (`systemd-journal` group); not independently re-hardened. |
| 5.2.1.1-5.2.1.2 | auditd installed and enabled | Implemented | `auditd` role | |
| 5.2.1.3 | `audit_backlog_limit` kernel boot parameter | **Skipped** | - | Requires a GRUB cmdline change and a reboot mid-build, which this project's single-boot Packer flow doesn't perform. |
| 5.2.1.4, 5.2.2.1-5.2.2.3 | Audit log storage size, retention, disk-full behavior | Implemented | `auditd` role | `admin_space_left_action=halt` by default - a real availability tradeoff, see README |
| 5.2.3.x, 5.2.4.x | Audit rules: identity, time, MAC policy, logins/sessions, DAC changes, unauthorized access, mounts, deletions, module (un)loading, sudoers, privileged commands | Implemented | `auditd` role | Privileged-command rules are generated from a live setuid/setgid binary scan |
| 5.3 | Log rotation configured | Implemented | `logging` role | |

## 6. System Maintenance

| ID | Control | Status | Where | Notes |
|----|---------|--------|-------|-------|
| 6.1.1-6.1.8 | Ownership/permissions on `passwd`/`group`/`shadow`/`gshadow` (+ backups) | Implemented | `common` role | |
| 6.1.9-6.1.12 | No world-writable, unowned, ungrouped, or stray SGID files anywhere on the filesystem | **Advisory** | Goss `goss_advisory.yaml` | A blind, recursive `chmod`/`chown` across the whole filesystem at build time is how you break package-managed files or intentionally world-writable sticky dirs (`/tmp`, `/var/tmp`, `/dev/shm`). Reported for a human to triage, not auto-remediated. |
| 6.2.1 | Shadowed passwords | Implemented | - | AL2023 default; verified via `/etc/shadow` permissions |
| 6.2.2-6.2.3 | System accounts secured / cannot log in interactively | Implemented | `common` role | Same task as 4.6.2 |
| 6.2.4 | root's default group is GID 0 | Implemented | `common` role | |
| 6.2.5 | Default user umask | Implemented | `common` role | Same as 4.6.6 |
| 6.2.6 | Login retries limited | **Skipped** | - | Depends on faillock (4.4.x/4.5.2), same reasoning. |
| 6.2.7-6.2.11 | Locked-account hygiene, invalid shells, interactive users' home directory settings | Not implemented | - | A freshly built AMI has no extra interactive users; this is provisioning-time concern for whatever tool creates your users (cloud-init, SSM, config management) downstream. |

## Beyond CIS: explicit project requirements

| Requirement | Status | Where |
|---|---|---|
| IMDSv2 required | Implemented | `packer/al2023.pkr.hcl` `metadata_options` |
| Encrypted root volume | Implemented | `packer/al2023.pkr.hcl` `launch_block_device_mappings` |
| No hardcoded users or keys | Implemented | Packer uses an ephemeral, auto-generated SSH keypair discarded at the end of the build; SSH is key-only (no passwords); no static accounts are created |
| SSM Agent preinstalled and enabled | Implemented | `common` role |
| CloudWatch Agent preinstalled and enabled | Implemented | `logging` role |
| chrony preinstalled and enabled | Implemented | `common` role |
| AIDE preinstalled and enabled | Implemented | `common` role |
