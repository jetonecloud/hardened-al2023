# Threat model note

This is a short note on what this project defends against, what it assumes,
and what it explicitly does not try to solve. It's scoped to the AMI and
the pipeline that builds it - not to whatever you deploy on top of it.

## Assets

- The confidentiality/integrity of data at rest on instances launched from
  this AMI (root volume).
- The integrity of the AMI build pipeline itself (no unauthorized code
  reaching a published AMI).
- SSH/administrative access to running instances.
- Audit evidence (can you reconstruct what happened on a box after the
  fact?).

## Threat actors considered

1. **Opportunistic internet scanners/bots** hitting a misconfigured
   instance (open SSH with weak auth, exposed management ports). This is
   the primary threat the `ssh` and `network` roles address.
2. **A compromised or careless CI/CD pipeline** publishing a backdoored or
   silently-broken AMI. Addressed by: no static AWS credentials (OIDC
   short-lived tokens only), a Goss gate that fails the build on critical
   control failures, a Trivy scan for known vulnerabilities/secrets before
   publish, and `sshd -t`/`visudo -cf` validation before any auth-affecting
   config is applied.
3. **An attacker who gets local, unprivileged code execution** on a
   running instance (e.g. via an application vulnerability) attempting to
   escalate privileges, persist, or move laterally. Addressed by: sudo/su
   hardening, restrictive umask, kernel module blacklisting, ptrace_scope,
   core dump restriction, and - critically - the audit trail (auditd rules
   + CloudWatch Logs shipping) that makes the attempt visible and
   reconstructable after the fact, even where it isn't prevented outright.
4. **Someone with legitimate AWS API access making a mistake** (e.g.
   accidentally leaving a root volume unencrypted, or IMDSv1 enabled so an
   SSRF bug becomes a full credential leak). Addressed by: encryption and
   IMDSv2 enforced unconditionally in the Packer template, not left as a
   default a caller could forget to set.

## Explicitly out of scope

- **Application-layer security of whatever you run on this AMI.** This
  hardens the OS, not your app's dependencies, auth logic, or business
  rules.
- **Network perimeter design.** The host firewall (firewalld, default-deny)
  is defense in depth; it is not a substitute for correctly scoped Security
  Groups, NACLs, and network segmentation, which this project does not and
  cannot control from inside the AMI.
- **Supply-chain compromise of upstream AL2023 packages or the AWS AMI
  pipeline itself.** This project trusts the official AL2023 AMI resolved
  via the AWS-published SSM parameter, and trusts `dnf`'s signed-repo
  verification for packages installed on top of it. If that trust is
  broken upstream, this project inherits the compromise.
- **Insider threat from someone with legitimate IAM permissions on the
  build pipeline's AWS account or GitHub repo admin access.** OIDC removes
  long-lived static credentials as an attack surface, but anyone who can
  modify `.github/workflows/pipeline.yml` or the roles it assumes can
  publish whatever AMI they want. Protect repo admin/branch-protection
  settings and the trust policy on the OIDC role accordingly.
- **Denial of service** against the instance or the build pipeline.
- **Physical security of underlying AWS hardware** - that's AWS's job
  under the shared responsibility model.
- **Compliance certification.** See the top of docs/controls.md: this
  project is CIS-*aligned*, not CIS-*certified*. Certification is an
  attestation process against your specific environment and isn't
  something an open-source template can grant you.

## A deliberate tradeoff worth calling out

`auditd_admin_space_left_action` defaults to `halt`: per CIS, a system that
can no longer guarantee it's recording an audit trail should stop rather
than silently lose events. That is a genuine availability tradeoff - a
full audit partition will take an instance down. For compliance-sensitive
workloads where non-repudiation matters more than uptime, that's the right
default. For a plain web server where uptime matters more, override it to
`syslog` in `ansible/roles/auditd/defaults/main.yml`. We'd rather you make
that call knowingly than have it made for you silently.
