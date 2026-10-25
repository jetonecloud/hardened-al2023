#!/usr/bin/env bash
# Runs the Goss profiles uploaded to /tmp/goss by the "file" provisioner.
#
# Files listed in CRITICAL_FILES gate the build: any failure here makes
# this script exit non-zero, which fails the Packer build and prevents
# a non-compliant AMI from ever being published.
#
# goss_advisory.yaml is informational only (e.g. "nice to have" controls
# or checks that are environment-dependent) and never fails the build.
set -uo pipefail

GOSS_DIR="/tmp/goss"
RESULTS="/tmp/goss-results.json"
ADVISORY_RESULTS="/tmp/goss-advisory-results.json"

CRITICAL_FILES=(
  goss_ssh.yaml
  goss_kernel.yaml
  goss_network.yaml
  goss_auditd.yaml
  goss_logging.yaml
  goss.yaml
)

overall_rc=0
suite_results=()

for f in "${CRITICAL_FILES[@]}"; do
  path="${GOSS_DIR}/${f}"
  [ -f "$path" ] || continue
  echo "==> goss validate ${f}"
  out="$(sudo GOSS_FILES_PATH="${GOSS_DIR}" goss -g "${path}" validate -f json)"
  rc=$?
  suite_results+=("$out")
  if [ "$rc" -ne 0 ]; then
    echo "!! ${f} reported failing controls"
    sudo GOSS_FILES_PATH="${GOSS_DIR}" goss -g "${path}" validate -f documentation || true
    overall_rc=1
  fi
done

{
  printf '['
  for i in "${!suite_results[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '%s' "${suite_results[$i]}"
  done
  printf ']'
} > "$RESULTS"

if [ -f "${GOSS_DIR}/goss_advisory.yaml" ]; then
  sudo GOSS_FILES_PATH="${GOSS_DIR}" goss -g "${GOSS_DIR}/goss_advisory.yaml" validate -f json > "$ADVISORY_RESULTS" || true
else
  echo '{"results":[],"summary":{"note":"no advisory suite present"}}' > "$ADVISORY_RESULTS"
fi

sudo chmod 644 "$RESULTS" "$ADVISORY_RESULTS"

echo "==> critical suite exit code: ${overall_rc}"
exit "$overall_rc"
