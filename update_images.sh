#!/bin/bash
set -euo pipefail

RELEASE_TAG="$(curl -s https://api.github.com/repos/lucasbeiler/firecracker-archlinux/releases | grep '"name"' | head -1 | cut -d'"' -f4 | sed 's/[^0-9]//g')"
RELEASE_URL="https://github.com/lucasbeiler/firecracker-archlinux/releases/download/${RELEASE_TAG}"

if [[ $RELEASE_TAG -gt $(cat .version_tag) ]]; then  
  rm -f initramfs-linux.img && curl -L -f --progress-bar -o "initramfs-linux.img" "$RELEASE_URL/initramfs-linux.img" || die "Failed initramfs download"
  rm -f vmlinux && curl -L -f --progress-bar -o "vmlinux" "$RELEASE_URL/vmlinux" || die "Failed kernel download"
  rm -f rootfs.squashfs && curl -L -f --progress-bar -o "rootfs.squashfs" "$RELEASE_URL/rootfs.squashfs" || die "Failed rootfs download"
  #curl -L -f --progress-bar -o "$WORKDIR/SHA256SUMS" "$RELEASE_URL/SHA256SUMS-${RELEASE_TAG}" || die "Failed SHA256SUMS download"
  #curl -L -f --progress-bar -o "$WORKDIR/SHA256SUMS.sig" "$RELEASE_URL/SHA256SUMS-${RELEASE_TAG}.sig" || die "Failed SHA256SUMS signature download"
fi
echo $RELEASE_TAG > .version_tag

[ -f data.ext4 ] && file data.ext4 | grep -q "ext4 filesystem" || { rm -f data.ext4 && truncate -s 15G data.ext4; }

# TODO: Add code to deal with checking if the rootfs is up-to-date and update when needed.
