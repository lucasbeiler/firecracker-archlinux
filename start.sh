#!/bin/bash
set -euo pipefail
TIMESTAMP=$(date +%s)

firecracker --api-sock /tmp/firecracker-${TIMESTAMP}.sock --config-file vm.config.json || rm -f /tmp/firecracker-${TIMESTAMP}.sock
rm -f /tmp/firecracker-${TIMESTAMP}.sock
