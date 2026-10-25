# Contributing

Thanks for considering a contribution to hardened-al2023. This is a
hardening template that other people will run against real AWS accounts -
please weigh changes accordingly.

## Ground rules

- **Tag every new/changed task with the CIS control ID(s) it implements**,
  e.g. `CIS 4.2.10 | ...`. If it's not a CIS control (e.g. the CloudWatch
  Agent setup), say what it's for instead.
- **Never add a control that risks locking out access** without a safety
  net. The `ssh` role validates config with `sshd -t` before applying it;
  the `auditd`/`network` roles are careful never to block the connection
  Ansible/Packer is currently using. Follow that pattern.
- **Default to safe, not maximal.** If a control has a real chance of
  breaking common workloads (see the "Skipped" rows in
  [docs/controls.md](docs/controls.md) - SELinux enforcing, unprivileged
  user namespaces, authselect/faillock), either leave it skipped with a
  clear reason, or add it behind an off-by-default variable, not as an
  unconditional change.
- **Be honest in the docs.** If you implement a control, add/update its
  row in `docs/controls.md` and the README's control matrix. If you skip
  one, say why - "too risky to guess at in a generic OSS role" is a
  perfectly good reason, vagueness is not.
- Never say "CIS-certified" anywhere in this repo. "CIS-aligned" or
  "CIS-inspired" only.

## Good first contributions

These are flagged in `docs/controls.md` as deliberately left out - they're
genuinely useful, just too environment-specific or high-risk for this
project to guess at by default:

- An `authselect` role that safely enables `pam_faillock`/`pam_pwhistory`
  (CIS 4.4.x/4.5.2/4.5.4) with a rollback-safe approach
- An optional partition-separation role for `/tmp`, `/var`, `/var/log`,
  etc. (CIS 1.1.2.x-1.1.7.x), for teams that provision extra EBS volumes
- A SELinux-enforcing role, off by default, with a pre-flight check that
  warns about `unconfined`/`unlabeled` processes before flipping the mode
- An InSpec profile as an alternative to the Goss suite in `tests/`

## Development workflow

```bash
ansible-galaxy collection install -r ansible/requirements.yml

# Format and validate
cd packer && packer fmt -recursive . && packer init al2023.pkr.hcl
packer validate -var-file=local.pkrvars.hcl al2023.pkr.hcl

# Lint
ansible-lint ansible/playbook.yml
yamllint .

# Build + test + scan locally (needs real AWS credentials and costs a
# few cents - see docs/cost-estimate.md)
packer build -var-file=local.pkrvars.hcl al2023.pkr.hcl
```

Or just `make lint`, `make validate`, `make build`.

## Pull requests

1. One control area per PR where possible (matches the role split) - it
   makes review tractable.
2. Update `docs/controls.md` and the README control matrix in the same PR.
3. Add or update a Goss check for anything you implement or change -
   "implemented" with no test backing it is not implemented.
4. Describe what you tested the change against (region, instance type,
   whether you ran a full `packer build`).
5. CI (lint/build/test/scan) must pass before merge. `build`/`test`/`scan`
   require repository AWS OIDC configuration - maintainers can trigger
   these manually for PRs from forks if you don't have your own AWS
   account to test against.

## Reporting bugs vs. security issues

Regular bugs: open a GitHub issue. Security issues (credential leakage,
auth bypass, pipeline trust-boundary weaknesses): see
[SECURITY.md](SECURITY.md) instead - don't open a public issue.
