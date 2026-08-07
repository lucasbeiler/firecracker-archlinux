#!/bin/bash
set -euo pipefail

#RELEASE_TAG="$(curl -s https://api.github.com/repos/lucasbeiler/firecracker-archlinux/releases | grep '"name"' | head -1 | cut -d'"' -f4 | sed 's/[^0-9]//g')"
#RELEASE_URL="https://github.com/lucasbeiler/firecracker-archlinux/releases/download/${RELEASE_TAG}"

[ -f data.ext4 ] && file data.ext4 | grep -q "ext4 filesystem" || { rm -f data.ext4 && truncate -s 15G data.ext4; }

# TODO: Add code to deal with checking if the rootfs is up-to-date and update when needed.
