#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +'%Y%m%d-%H%M%S')"
OUT="${HOME}/Documents/system-audit-${STAMP}.txt"

hdr(){ echo -e "\n===== $* =====\n" | tee -a "$OUT"; }
run(){ echo "\$ $*" | tee -a "$OUT"; ( "$@" 2>&1 || true ) | sed 's/\x1b\[[0-9;]*m//g' | tee -a "$OUT"; echo | tee -a "$OUT"; }
maybe(){ command -v "$1" >/dev/null 2>&1 && run "$@" || echo "(skip: $1 not found)" | tee -a "$OUT"; }

echo "Arch system audit - $(date)" > "$OUT"

# OS / kernel / boot
hdr "OS & Kernel"
run uname -a
run cat /etc/os-release
run cat /proc/cmdline
maybe sysctl -a | grep -E '(^kernel\.|^vm\.|^fs\.)'
maybe cat /proc/sched_debug | head -n 40
maybe ls -l /boot
maybe bootctl status
maybe grub-install --version

# CPU / microcode / topology / features
hdr "CPU & Microcode"
run lscpu
run cat /proc/cpuinfo | grep -m1 'model name'
run cat /proc/cpuinfo | grep -m1 'flags'
maybe journalctl -k -b 0 --no-pager | grep -i microcode | tail -n +1

# Memory / NUMA / hugepages
hdr "Memory & Hugepages"
run free -h
maybe numactl --hardware
run sysctl vm.nr_hugepages
run awk '/Huge/ {print}' /proc/meminfo

# Motherboard / BIOS / DMI
hdr "DMI / SMBIOS"
maybe sudo dmidecode -t baseboard
maybe sudo dmidecode -t bios
maybe sudo dmidecode -t processor | sed -n '1,80p'

# PCI / USB / devices
hdr "PCI devices (concise)"
run lspci
hdr "PCI devices (verbose, no caps)"
maybe lspci -nnk
hdr "USB devices"
run lsusb

# Graphics / display / video acceleration
hdr "Graphics & Display"
maybe inxi -Gxx
maybe hwinfo --gfxcard --short
maybe glxinfo -B
maybe vulkaninfo | head -n 60
maybe lsmod | grep -E 'nvidia|amdgpu|i915|nouveau'

# Storage / filesystems / NVMe features
hdr "Storage"
run lsblk -o NAME,MODEL,SIZE,TYPE,ROTA,MOUNTPOINTS
maybe nvme list
maybe sudo smartctl --scan
maybe sudo smartctl -x /dev/sda
maybe sudo smartctl -x /dev/nvme0
run cat /proc/filesystems
maybe zpool status
maybe btrfs filesystem df -H / 2>/dev/null || true
maybe xfs_info / 2>/dev/null || true

# Network
hdr "Network"
run ip -br addr
maybe ethtool -i "$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"
maybe iw dev
maybe rfkill list

# Audio (PipeWire/ALSA)
hdr "Audio"
maybe inxi -Ax
run aplay -l || true
run pactl info || true

# Sensors / thermals / power
hdr "Sensors / Thermals / Power"
maybe sensors
maybe tlp-stat -s
maybe upower -i $(upower -e | head -n1)
maybe cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

# Firmware / Secure Boot / EFI
hdr "Firmware / Secure Boot / EFI"
maybe fwupdmgr get-devices
maybe mokutil --sb-state
maybe ls /sys/firmware/efi/efivars | wc -l

# Kernel modules in use (top)
hdr "Loaded Modules (sorted by size)"
run lsmod | sort -k2 -n | tail -n 40

# Kernel messages (recent, curated)
hdr "Kernel dmesg (errors & warnings)"
run dmesg --ctime --level=err,warn | tail -n 300

# Display server
hdr "Display Server"
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}" | tee -a "$OUT"
maybe ps -e | grep -E 'Xorg|Xwayland|wayland|Hyprland'

# Packages (brief)
hdr "Package counts"
run pacman -Q | wc -l
run pacman -Qe | wc -l
run pacman -Qm | wc -l

echo -e "\nWrote: ${OUT}"

