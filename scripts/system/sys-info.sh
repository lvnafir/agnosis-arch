#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +'%Y%m%d-%H%M%S')"
OUT="${HOME}/Documents/sys-info-audit-${STAMP}.txt"

hdr(){ echo -e "\n======================================================================\n$*\n----------------------------------------------------------------------" | tee -a "$OUT"; }
run(){ echo -e "\n$ $*" | tee -a "$OUT"; ( "$@" 2>&1 || true ) | tee -a "$OUT"; }
maybe(){ command -v "$1" >/dev/null 2>&1 && run "$@" || echo "(skip: $1 not found)" | tee -a "$OUT"; }

echo "Arch System Audit — $(date)" > "$OUT"

# OS & Kernel
hdr "OS & KERNEL"
run uname -a
run cat /etc/os-release
run cat /proc/cmdline

# CPU
hdr "CPU INFO"
run lscpu
grep -m1 "model name" /proc/cpuinfo | tee -a "$OUT"
grep -m1 "flags" /proc/cpuinfo | tee -a "$OUT"

# GPU / Graphics
hdr "GRAPHICS"
maybe inxi -Gxx
maybe lspci | grep -Ei 'vga|3d'
maybe glxinfo -B
maybe vulkaninfo | head -n 40

# Memory
hdr "MEMORY"
run free -h
run awk '/Huge/ {print}' /proc/meminfo

# Storage
hdr "STORAGE"
run lsblk -o NAME,MODEL,SIZE,ROTA,MOUNTPOINTS,FSTYPE
maybe df -h
maybe sudo smartctl --scan

# Network
hdr "NETWORK"
ip -br addr | tee -a "$OUT"
run sysctl net.ipv4.tcp_congestion_control
run sysctl net.core.default_qdisc

# Sysctl Hardening / Tunables
hdr "SYSCTL SNAPSHOT"
for key in \
  kernel.unprivileged_userns_clone \
  kernel.unprivileged_bpf_disabled \
  kernel.yama.ptrace_scope \
  kernel.kptr_restrict \
  kernel.dmesg_restrict \
  fs.file-max \
  fs.inotify.max_user_watches \
  vm.max_map_count \
  vm.swappiness \
  ; do
  sysctl -n $key 2>/dev/null | xargs -I{} echo "$key = {}" | tee -a "$OUT"
done

# Processes / Load
hdr "LOAD & PROCESSES"
run uptime
run ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 15

# Suggested tunings (static recommendations)
hdr "SUGGESTED TUNINGS"
cat <<'EOF' | tee -a "$OUT"
- Enable zswap: add 'zswap.enabled=1' to kernel cmdline if desired
- Consider sysctl net.ipv4.tcp_congestion_control = bbr
- Consider sysctl kernel.kptr_restrict = 2
- Tune vm.swappiness = 10 for SSDs
- Review kernel.unprivileged_userns_clone = 1 (disable if no Flatpak/Chrome required)
EOF

echo -e "\nAudit complete. Output saved to $OUT"

