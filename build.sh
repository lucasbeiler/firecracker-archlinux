#!/bin/bash
set -euo pipefail
WORKDIR="rootfs"
OUTPUT="/images"
mkdir -pv ${WORKDIR} ${OUTPUT}

BASE_DEVEL_WITHOUT_SUDO=$(LANG=en_US pacman -Sii base-devel | grep ^Depends | cut -d ':' -f2 | sed 's/sudo//g')
pacstrap -c -K -P ${WORKDIR} base ${BASE_DEVEL_WITHOUT_SUDO} linux bash openssh helix tmux dhclient doas aws-cli azure-cli checksec git repo bubblewrap-suid docker docker-compose jq yq patchutils iptables eza dnscrypt-proxy ntpd-rs kubectl kustomize fluxcd sops age opentofu 

arch-chroot $WORKDIR /bin/bash -s <<'CHROOT'
#!/bin/bash
set -euxo pipefail

mkdir -p /etc/initcpio/hooks /etc/initcpio/install

cat > /etc/initcpio/hooks/bindboot <<'HOOK'
run_hook() {
    mount_handler="bindboot_mount_handler"
}

bindboot_mount_handler() {
    newroot="$1"

    # root is the squashfs itself, read-only
    mount -t squashfs -o ro /dev/vda "$newroot"

    fstype=$(blkid -o value -s TYPE /dev/vdb 2>/dev/null || true)
    if [ -z "$fstype" ]; then
        echo "bindboot: /dev/vdb has no filesystem, formatting ext4..."
        mkfs.ext4 -F -q /dev/vdb
    else
        echo "bindboot: /dev/vdb already formatted ($fstype), keeping as-is"
    fi

    mkdir -p /vdb
    mount /dev/vdb /vdb
    mkdir -p /vdb/var /vdb/home

    # seed persistent dirs from the image on first boot
    if [ ! -d /vdb/var/lib ]; then
        cp -a "$newroot/var/." /vdb/var/
    fi
    if [ -z "$(ls -A /vdb/home 2>/dev/null)" ]; then
        cp -a "$newroot/home/." /vdb/home/
    fi

    mkdir -p "$newroot/mnt/"
    mount --move /vdb "$newroot/mnt/"

    mount --bind "$newroot/mnt/var" "$newroot/var"
    mount --bind "$newroot/mnt/home" "$newroot/home"
}
HOOK

cat > /etc/initcpio/install/bindboot <<'INSTALL'
build() {
    add_module squashfs
    add_binary blkid
    add_binary mkfs.ext4
    add_binary mount
    add_binary cp
    add_runscript
}
help() {
    echo "bind squashfs(vda) + ext4(vdb) as root"
}
INSTALL

systemctl enable multi-user.target
sed -i 's/^PRESETS=(.*/PRESETS=('"'"'default'"'"')/' /etc/mkinitcpio.d/linux.preset
sed -i 's/^MODULES=(/MODULES=(virtio_mmio /' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block bindboot filesystems)/' /etc/mkinitcpio.conf
mkinitcpio -P

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-eth0.network <<'NET'
[Match]
Name=eth0

[Network]
Address=172.16.0.2/30
Gateway=172.16.0.1
NET


echo "permit persist :wheel" > /etc/doas.conf
chmod 400 /etc/doas.conf

useradd -m -G wheel,users,power,audio,video,network -s /bin/bash work
mkdir -p /home/work/.ssh
chmod 700 /home/work/.ssh
cat > /home/work/.ssh/authorized_keys <<'PUBKEY'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7VdInHhXmM7S+/ZS1k28VjExEw6NEc5zZW0RO9xfbx work@computer
PUBKEY
chmod 600 /home/work/.ssh/authorized_keys
chown -R work:work /home/work/.ssh

# sshd: key-only, allow work (and optionally root)
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'SSHD'
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers work root
SSHD

ssh-keygen -A
systemctl enable systemd-networkd docker sshd

echo "root:changeme" | chpasswd
echo "work:changeme" | chpasswd
CHROOT

cp ${WORKDIR}/boot/initramfs-linux.img ${OUTPUT}/initramfs-linux.img
curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux > extract-vmlinux.sh
bash extract-vmlinux.sh ${WORKDIR}/boot/vmlinuz-linux > ${OUTPUT}/vmlinux

echo "nameserver 9.9.9.9" > ${WORKDIR}/etc/resolv.conf # TODO: dnscrypt-proxy...
mksquashfs ${WORKDIR} ${OUTPUT}/rootfs.squashfs -comp zstd -noappend -e boot
