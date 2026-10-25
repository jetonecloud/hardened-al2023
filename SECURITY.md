# Security Policy

## Supported versions

This project ships as a Packer/Ansible source template, not a running
service - there's no "supported version" in the traditional sense. Security
fixes land on `main` and are called out in [CHANGELOG.md](CHANGELOG.md).
If you built an AMI from an older commit, rebuild from current `main` to
pick up fixes.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Preferred: use GitHub's private vulnerability reporting for this
repository (**Security** tab -> **Report a vulnerability**). This reaches
maintainers directly without disclosing the issue publicly.

Alternative: email **security@usejetone.com** with:

- A description of the issue and its potential impact
- Steps to reproduce (a minimal Packer/Ansible config diff is ideal)
- Any suggested remediation, if you have one

We aim to acknowledge reports within 5 business days and to agree on a
disclosure timeline with the reporter before any public write-up.

## What counts as a security issue here

In scope:

- A hardening role that silently fails to apply a control it claims to
  implement (see [docs/controls.md](docs/controls.md) for what's claimed)
- A change that would lock out legitimate SSH/sudo access
- A Packer/Ansible change that could leak credentials, tokens, or SSH keys
  into the resulting AMI, build logs, or CI artifacts
- A CI/CD pipeline change that weakens the OIDC trust boundary or allows
  publishing an AMI without passing the test/scan gates
- A dependency (pinned Goss/Trivy/Packer plugin version) with a known
  exploitable vulnerability

Out of scope (please use regular issues/PRs instead):

- Vulnerabilities in upstream Amazon Linux 2023 packages themselves -
  report those to AWS
- "Missing" controls that are already listed and explained in
  [docs/controls.md](docs/controls.md) as deliberately skipped
- Requests to add CIS Level 2 or STIG controls
