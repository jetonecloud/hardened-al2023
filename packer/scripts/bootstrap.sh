#!/usr/bin/env bash
# Runs before Ansible: wait for cloud-init to settle and make sure the
# interpreter Ansible needs is present. AL2023 ships python3 by default,
# but we don't assume that stays true forever.
set -euo pipefail

echo "==> waiting for cloud-init"
timeout 300 bash -c 'until sudo cloud-init status --wait >/dev/null 2>&1; do sleep 2; done' || true

echo "==> refreshing dnf metadata"
sudo dnf -y makecache

if ! command -v python3 >/dev/null 2>&1; then
  sudo dnf -y install python3
fi

python3 --version
