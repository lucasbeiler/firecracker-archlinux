#!/bin/bash
set -euo pipefail
TIMESTAMP=$(date +%s)

[ -f data.ext4 ] && file data.ext4 | grep -q "ext4 filesystem" || { rm -f data.ext4 && truncate -s 15G data.ext4; }

# TODO: Add code to deal with checking if the rootfs is up-to-date and update when needed.

firecracker --api-sock /tmp/firecracker-${TIMESTAMP}.sock --config-file vm.config.json || rm -f /tmp/firecracker-${TIMESTAMP}.sock
rm -f /tmp/firecracker-${TIMESTAMP}.sock
