#!/usr/bin/env bash
# Installs a pinned trivy release used for the post-build scan stage.
set -euo pipefail

TRIVY_VERSION="${TRIVY_VERSION:?TRIVY_VERSION must be set}"

case "$(uname -m)" in
  x86_64)  TRIVY_ARCH="64bit" ;;
  aarch64) TRIVY_ARCH="ARM64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

URL="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz"

echo "==> installing trivy ${TRIVY_VERSION} (${TRIVY_ARCH})"
curl -fsSL "${URL}" -o "${TMP_DIR}/trivy.tar.gz"
tar -xzf "${TMP_DIR}/trivy.tar.gz" -C "${TMP_DIR}" trivy
sudo mv "${TMP_DIR}/trivy" /usr/local/bin/trivy
sudo chmod 755 /usr/local/bin/trivy
trivy --version
