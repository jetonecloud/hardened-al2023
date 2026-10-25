# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to follow [Semantic Versioning](https://semver.org/)
for its tagged releases (`vMAJOR.MINOR.PATCH`), which the CI pipeline uses
as the AMI's version tag.

## [Unreleased]

## [0.1.0] - 2026-10-25

### Added

- Initial release: Packer HCL2 build (`packer/al2023.pkr.hcl`) resolving
  the latest AL2023 AMI via SSM parameter, enforcing IMDSv2 and an
  encrypted root volume, with no hardcoded users or keys.
- Ansible hardening roles, one per control group: `common`, `ssh`,
  `kernel`, `network`, `auditd`, `logging`, each task tagged with the CIS
  control ID(s) it implements.
- Goss compliance test suite (`tests/goss/`), blocking on critical control
  failures, with a non-blocking advisory suite for audit-only controls.
- Trivy filesystem/vulnerability/secret scan run at build time, with the
  report published as a pipeline artifact.
- GitHub Actions pipeline (`.github/workflows/pipeline.yml`): lint, build
  (AWS OIDC, no static keys), test, scan, and publish stages, plus a
  weekly scheduled rebuild.
- Documentation: README quick start, full CIS control matrix
  (implemented/skipped/advisory, with reasons), required IAM policy, cost
  estimate, and threat model note (`docs/`).
- `LICENSE` (Apache-2.0), `SECURITY.md`, `CONTRIBUTING.md`.

[Unreleased]: https://github.com/jetonecloud/hardened-al2023/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jetonecloud/hardened-al2023/releases/tag/v0.1.0
