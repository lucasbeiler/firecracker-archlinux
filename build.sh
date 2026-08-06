#!/bin/bash
set -euo pipefail
WORKDIR="mountpoint"
OUTPUT="/images"
ROOTFS="${OUTPUT}/rootfs.ext4"

mkdir -pv ${WORKDIR} ${OUTPUT}

truncate --size=1G "$ROOTFS"
mkfs.ext4 "$ROOTFS"

mount ${ROOTFS} ${WORKDIR}

pacstrap -P -c -K ${WORKDIR} base linux bash openssh helix tmux dhclient doas

arch-chroot $WORKDIR /bin/bash -s <<'CHROOT'
#!/bin/bash
set -euxo pipefail

systemctl enable multi-user.target systemd-repart
sed -i 's/^PRESETS=(.*/PRESETS=('"'"'default'"'"')/' /etc/mkinitcpio.d/linux.preset
sed -i 's/MODULES=(/MODULES=(virtio_mmio ext4 /' /etc/mkinitcpio.conf
systemctl enable multi-user.target 2>/dev/null
systemctl set-default multi-user.target

mkinitcpio -P

mkdir -p /etc/repart.d
cat > /etc/repart.d/50-home.conf <<'EOF'
[Partition]
Type=home
Format=ext4
Label=home
SizeMinBytes=512M
EOF

echo '/dev/vdb  /home  ext4  defaults,x-systemd.growfs  0  2' >> /etc/fstab

echo "root:changeme" | chpasswd
CHROOT

cp ${WORKDIR}/boot/initramfs-linux.img ${OUTPUT}/initramfs-linux.img
curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux > extract-vmlinux.sh
bash extract-vmlinux.sh ${WORKDIR}/boot/vmlinuz-linux > ${OUTPUT}/vmlinux

sleep 5; umount -R ${WORKDIR} || :
