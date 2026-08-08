#!/bin/bash
set -euo pipefail
WORKDIR="rootfs"
OUTPUT="/images"
mkdir -pv ${WORKDIR} ${OUTPUT}

BASE_DEVEL_WITHOUT_SUDO=$(LANG=en_US pacman -Sii base-devel | grep ^Depends | cut -d ':' -f2 | sed 's/sudo//g')
pacstrap -c -K -P ${WORKDIR} base ${BASE_DEVEL_WITHOUT_SUDO} linux bash openssh helix tmux dhclient doas aws-cli azure-cli checksec git repo bubblewrap-suid docker docker-compose jq yq patchutils iptables eza dnscrypt-proxy ntpd-rs kubectl kustomize fluxcd sops age opentofu zip unrar unzip fastfetch dosfstools mtools nmap

# Build GrapheneOS' hardened_malloc.
pacman -Sy --noconfirm just go git apparmor
id -u builder &>/dev/null || useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/builder
su builder -s /bin/bash <<'EOF'
set -euo pipefail
# Declare variables.
H_MALLOC_UPSTREAM_COMMIT=1976e09730897c49906dea4ce054ca937c47e0be   # Update this to the commit hash last reviewed at https://github.com/GrapheneOS/hardened_malloc

# Fetch and build hardened_malloc.
rm -rf /tmp/hardened_malloc
git clone https://github.com/grapheneos/hardened_malloc /tmp/hardened_malloc
cd /tmp/hardened_malloc
git checkout "$H_MALLOC_UPSTREAM_COMMIT"
rm -rf out/*
make clean
make
EOF
cp /tmp/hardened_malloc/out/libhardened_malloc.so "${WORKDIR}/usr/lib/"

cp -r root_files/* ${WORKDIR}/

arch-chroot $WORKDIR /bin/bash -s <<'CHROOT'
#!/bin/bash
set -euxo pipefail

patch /etc/dnscrypt-proxy/dnscrypt-proxy.toml /etc/patch_dnscryptproxy_toml.patch

useradd -m -G wheel,docker,users,power,audio,video,network -s /bin/bash work
mkdir -p /home/work/.ssh
chmod 700 /home/work/.ssh
cat > /home/work/.ssh/authorized_keys <<'PUBKEY'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7VdInHhXmM7S+/ZS1k28VjExEw6NEc5zZW0RO9xfbx work@computer
PUBKEY
chmod 600 /home/work/.ssh/authorized_keys
chown -R work:work /home/work/.ssh

ssh-keygen -A
systemctl enable multi-user.target systemd-networkd docker sshd dnscrypt-proxy

mkdir /data

echo "root:changeme" | chpasswd
echo "work:changeme" | chpasswd

mkinitcpio -P
CHROOT

cp ${WORKDIR}/boot/initramfs-linux.img ${OUTPUT}/initramfs-linux.img
curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux > extract-vmlinux.sh
bash extract-vmlinux.sh ${WORKDIR}/boot/vmlinuz-linux > ${OUTPUT}/vmlinux

rm -rf ${WORKDIR}/boot/*
mksquashfs ${WORKDIR} ${OUTPUT}/rootfs.squashfs -comp zstd -noappend -e boot
