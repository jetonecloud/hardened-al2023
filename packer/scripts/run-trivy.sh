#!/usr/bin/env bash
# Scans the hardened root filesystem for known vulnerabilities, exposed
# secrets, and misconfigurations before the instance is baked into an AMI.
#
# By default this never fails the build (TRIVY_FAIL_ON_CRITICAL=false):
# the report is published as a pipeline artifact and the GitHub Actions
# "scan" job is what decides whether CRITICAL findings block publishing.
# Set TRIVY_FAIL_ON_CRITICAL=true to also gate the Packer build itself.
set -uo pipefail

SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH}"
FAIL_ON_CRITICAL="${TRIVY_FAIL_ON_CRITICAL:-false}"
REPORT="/tmp/trivy-report.json"

exit_code=0
if [ "$FAIL_ON_CRITICAL" = "true" ]; then
  exit_code=1
fi

sudo trivy fs \
  --scanners vuln,secret,misconfig \
  --severity "${SEVERITY}" \
  --exit-code "${exit_code}" \
  --format json \
  --output "${REPORT}" \
  --skip-dirs "/proc,/sys,/tmp/goss" \
  /

rc=$?
sudo chmod 644 "${REPORT}"
echo "==> trivy scan exit code: ${rc}"
exit "${rc}"
