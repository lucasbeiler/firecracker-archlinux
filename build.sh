#!/bin/bash
set -euo pipefail
WORKDIR="rootfs"
OUTPUT="/images"
mkdir -pv ${WORKDIR} ${OUTPUT}

BASE_DEVEL_WITHOUT_SUDO=$(LANG=en_US pacman -Sii base-devel | grep ^Depends | cut -d ':' -f2 | sed 's/sudo//g')
pacstrap -c -K ${WORKDIR} base ${BASE_DEVEL_WITHOUT_SUDO} linux bash openssh helix tmux dhclient doas aws-cli azure-cli checksec bubblewrap-suid docker docker-compose jq yq patchutils iptables eza dnscrypt-proxy ntpd-rs kubectl kustomize fluxcd sops age opentofu 

arch-chroot $WORKDIR /bin/bash -s <<'CHROOT'
#!/bin/bash
set -euxo pipefail

mkdir -p /etc/initcpio/hooks /etc/initcpio/install

cat > /etc/initcpio/hooks/overlayboot <<'HOOK'
run_hook() {
    mount_handler="overlayboot_mount_handler"
}

overlayboot_mount_handler() {
    newroot="$1"
    mkdir -p /lower /upper
    mount -t squashfs -o ro /dev/vda /lower

    fstype=$(blkid -o value -s TYPE /dev/vdb 2>/dev/null || true)
    if [ -z "$fstype" ]; then
        echo "overlayboot: /dev/vdb has no filesystem, formatting ext4..."
        mkfs.ext4 -F -q /dev/vdb
    else
        echo "overlayboot: /dev/vdb already formatted ($fstype), keeping as-is"
    fi

    mount /dev/vdb /upper
    mkdir -p /upper/data /upper/work
    mount -t overlay overlay \
        -o lowerdir=/lower,upperdir=/upper/data,workdir=/upper/work \
        "$newroot"

    mkdir -p "$newroot/mnt/lower" "$newroot/mnt/vdb"
    mount --move /lower "$newroot/mnt/lower"
    mount --move /upper "$newroot/mnt/vdb"
}
HOOK

cat > /etc/initcpio/install/overlayboot <<'INSTALL'
build() {
    add_module overlay
    add_module squashfs
    add_binary blkid
    add_binary mkfs.ext4
    add_binary mount
    add_runscript
}
help() {
    echo "overlay squashfs(vda) + ext4(vdb) as root"
}
INSTALL

systemctl enable multi-user.target
sed -i 's/^PRESETS=(.*/PRESETS=('"'"'default'"'"')/' /etc/mkinitcpio.d/linux.preset
sed -i 's/^MODULES=(/MODULES=(virtio_mmio /' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block overlayboot filesystems)/' /etc/mkinitcpio.conf
mkinitcpio -P
echo "root:changeme" | chpasswd
CHROOT

cp ${WORKDIR}/boot/initramfs-linux.img ${OUTPUT}/initramfs-linux.img
curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux > extract-vmlinux.sh
bash extract-vmlinux.sh ${WORKDIR}/boot/vmlinuz-linux > ${OUTPUT}/vmlinux

mksquashfs ${WORKDIR} ${OUTPUT}/rootfs.squashfs -comp zstd -noappend -e boot
