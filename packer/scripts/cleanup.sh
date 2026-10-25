#!/usr/bin/env bash
# Bake hygiene: remove build-only tooling and transient state so the
# resulting AMI doesn't carry scan/test tooling, logs, or shell history.
set -euo pipefail

sudo rm -f /usr/local/bin/goss /usr/local/bin/trivy
sudo rm -rf /tmp/goss /tmp/*.json

sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
sudo truncate -s 0 /var/log/wtmp /var/log/btmp /var/log/lastlog 2>/dev/null || true
sudo cloud-init clean --logs || true

sudo rm -f /root/.bash_history
rm -f "${HOME}/.bash_history"
history -c || true

sudo rm -rf /tmp/* /var/tmp/*
