A minimal Arch Linux guest environment for the Firecracker VMM, built ([in CI](https://github.com/lucasbeiler/firecracker-archlinux/releases)) entirely from official Arch Linux packages, requiring no custom kernel compilation, external patches, or third-party prebuilt binaries.

Firecracker is an open-source, Rust-written microVM monitor (VMM) by Amazon (powering AWS Lambda and Fargate). It uses the KVM hypervisor. As Firecracker is minimal and security-focused, it substantially reduces the attack surface compared to traditional VMMs. Also, the `firecracker` binary in your host system is sandboxed by design.

For network setup, run `sudo bash ./firecracker-net-up`.

## Why?
[My host OS](https://github.com/lucasbeiler/archlinux-desktop-verity) is heavily security-hardened with an immutable root filesystem backed by `dm-verity` for strict integrity and authenticity. While secure, this limits flexibility for development and experimentation.

### Why VMs (Firecracker+KVM) instead of containers (Docker or Podman)?
* **Podman:** Requires (unprivileged) user namespaces (userns), which expands the host attack surface.
  * While AppArmor can restrict `userns` usage per process, the CrackArmor vulnerability showed that AppArmor isn't that good for that...
* **Docker:** Requires a privileged system service.

Instead, running an Arch environment inside a Firecracker KVM microVM keeps the host OS minimal and trusted while providing a flexible, isolated workspace.
