#!/usr/bin/env bash
# Installs a pinned goss release used to run the compliance test suite.
set -euo pipefail

GOSS_VERSION="${GOSS_VERSION:?GOSS_VERSION must be set}"

case "$(uname -m)" in
  x86_64)  GOSS_ARCH="amd64" ;;
  aarch64) GOSS_ARCH="arm64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

URL="https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${GOSS_ARCH}"

echo "==> installing goss ${GOSS_VERSION} (${GOSS_ARCH})"
sudo curl -fsSL "${URL}" -o /usr/local/bin/goss
sudo chmod 755 /usr/local/bin/goss
goss --version
