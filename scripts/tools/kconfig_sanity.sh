#!/usr/bin/env bash
# kconfig_sanity.sh — robust kernel .config auditor for a single machine (Arch-friendly)
# It scans your current kernel .config + actual hardware and writes a fixes fragment
# you can merge with:  merge_config.sh -m .config /path/to/noesis-fixes-*.config
set -euo pipefail

# ---------- locate .config ----------
CONFIG_PATH="${1:-}"
if [[ -z "${CONFIG_PATH}" ]]; then
  for c in "$PWD/.config" "$PWD/src/linux-*/.config" "$HOME/build/kernel/linux-zen/src/linux-*/.config"; do
    for f in $(compgen -G "$c" || true); do CONFIG_PATH="$f"; break; done
    [[ -n "${CONFIG_PATH}" ]] && break
  done
fi
[[ -n "${CONFIG_PATH:-}" && -f "$CONFIG_PATH" ]] || { echo "ERROR: .config not found"; exit 1; }

# ---------- outputs ----------
ts="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/Documents/kconfig-sanity-$ts.txt"
FIX="$HOME/Documents/noesis-fixes-$ts.config"
mkdir -p "$HOME/Documents"
: >"$OUT"; : >"$FIX"

log(){ printf "%s\n" "$*" | tee -a "$OUT"; }
have(){ grep -Eq "^[[:space:]]*$1=(y|m)" "$CONFIG_PATH"; }
off(){  grep -Eq "^[[:space:]]*# $1 is not set" "$CONFIG_PATH"; }
val(){  grep -E  "^[[:space:]]*$1=" "$CONFIG_PATH" || true; }
add_fix(){ # add_fix CONFIG_FOO y|m|n   (last-one-wins when merged)
  local sym="$1" mode="${2:-m}"
  printf "%s=%s\n" "$sym" "$mode" >> "$FIX"
  printf "ADD: %s=%s\n" "$sym" "$mode" | tee -a "$OUT"
}
rule(){ log ""; log "== $1 =="; }

# ---------- environment probes (best effort; resilient) ----------
lspci_out="$(lspci -nn 2>/dev/null || true)"
lsusb_out="$(lsusb 2>/dev/null || true)"
lsmod_out="$(lsmod 2>/dev/null || true)"

# Root FS
rootfs="$(findmnt -no FSTYPE / 2>/dev/null || awk '$2=="/"{print $3}' /etc/fstab 2>/dev/null | head -n1)"
[[ -z "${rootfs:-}" ]] && rootfs="ext4"

# Presence heuristics (multiple signals)
has_nvme=$(
  if grep -qi 'Non-Volatile memory controller' <<<"$lspci_out"; then echo yes
  elif grep -q '^nvme\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)
has_intel_eth=$(
  if grep -qiE 'Ethernet controller:.*Intel' <<<"$lspci_out"; then echo yes
  elif grep -qE '^(e1000e|igc)\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)
has_intel_wifi=$(
  if grep -qiE 'Network controller:.*(Intel|Wireless|AX[12]0[01])' <<<"$lspci_out"; then echo yes
  elif grep -q '^iwlwifi\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)
has_rtsx=$(
  if grep -qiE 'Realtek.*(RTS52|RTS525|Card Reader|10ec:525a)' <<<"$lspci_out"; then echo yes
  elif grep -q '^rtsx_pci\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)
has_bison_cam=$(
  if grep -qiE '(Bison|5986:)' <<<"$lsusb_out"; then echo yes
  elif grep -q '^uvcvideo\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)
has_usb4=$(
  if grep -qiE '(Thunderbolt|USB4|15d9:|8086:15d9)' <<<"$lspci_out"; then echo yes
  else echo no; fi
)
has_typec_stack=$(
  if grep -qE '^(typec|ucsi_acpi|tps6598x|ucsi_ccg)\>' <<<"$lsmod_out"; then echo yes
  else echo no; fi
)

log "Kernel config audit: $CONFIG_PATH"
log "Report: $OUT"
log "Proposed fixes fragment: $FIX"
log "Detected: rootfs=${rootfs}, NVMe=$has_nvme, IntelWiFi=$has_intel_wifi, IntelEth=$has_intel_eth, RTSX=$has_rtsx, BisonCam=$has_bison_cam, USB4=$has_usb4, Type-C stack=$has_typec_stack"

# ---------- Filesystems ----------
rule "Filesystems"
case "${rootfs:-}" in
  ext4) have CONFIG_EXT4_FS || add_fix CONFIG_EXT4_FS y ;;
  btrfs) have CONFIG_BTRFS_FS || add_fix CONFIG_BTRFS_FS y ;;
  xfs)  have CONFIG_XFS_FS   || add_fix CONFIG_XFS_FS   y ;;
  f2fs) have CONFIG_F2FS_FS  || add_fix CONFIG_F2FS_FS  y ;;
  *) log "INFO: rootfs=$rootfs (no explicit enable; double-check if unusual)";;
esac
have CONFIG_FAT_FS   || add_fix CONFIG_FAT_FS   m
have CONFIG_VFAT_FS  || add_fix CONFIG_VFAT_FS  m
have CONFIG_EXFAT_FS || add_fix CONFIG_EXFAT_FS m
have CONFIG_NTFS3_FS || add_fix CONFIG_NTFS3_FS m

# ---------- Storage ----------
rule "Storage"
if [[ "$has_nvme" == "yes" ]]; then
  have CONFIG_BLK_DEV_NVME || add_fix CONFIG_BLK_DEV_NVME m
  have CONFIG_NVME_CORE    || add_fix CONFIG_NVME_CORE    m
fi
# Keep SATA AHCI around unless you’re NVMe-only forever:
have CONFIG_ATA || log "WARN: CONFIG_ATA is off (OK if NVMe-only)"

# ---------- USB / Type-C / USB4 ----------
rule "USB / Type-C / USB4"
have CONFIG_USB_SUPPORT   || add_fix CONFIG_USB_SUPPORT y
have CONFIG_USB_XHCI_HCD  || add_fix CONFIG_USB_XHCI_HCD y
if [[ "$has_usb4" == "yes" ]]; then
  have CONFIG_USB4 || add_fix CONFIG_USB4 m
fi
# Type-C policy mgrs/UCSI/role switch are small but important
have CONFIG_TYPEC        || add_fix CONFIG_TYPEC y
have CONFIG_TYPEC_UCSI   || add_fix CONFIG_TYPEC_UCSI m
have CONFIG_UCSI_ACPI    || add_fix CONFIG_UCSI_ACPI m
have CONFIG_USB_ROLE_SWITCH || add_fix CONFIG_USB_ROLE_SWITCH m

# USB networking/tethering quality-of-life
have CONFIG_USB_USBNET         || add_fix CONFIG_USB_USBNET m
have CONFIG_USB_NET_CDC_NCM    || add_fix CONFIG_USB_NET_CDC_NCM m
have CONFIG_USB_NET_RNDIS_HOST || add_fix CONFIG_USB_NET_RNDIS_HOST m
have CONFIG_USB_RTL8152        || add_fix CONFIG_USB_RTL8152 m

# ---------- Input / HID / Gamepad ----------
rule "Input / HID / Gamepad"
have CONFIG_HID_GENERIC    || add_fix CONFIG_HID_GENERIC y
have CONFIG_HID_MULTITOUCH || add_fix CONFIG_HID_MULTITOUCH m
have CONFIG_INPUT_JOYDEV   || add_fix CONFIG_INPUT_JOYDEV m
have CONFIG_JOYSTICK_XPAD  || add_fix CONFIG_JOYSTICK_XPAD m
have CONFIG_UINPUT         || add_fix CONFIG_UINPUT m

# ---------- Camera (UVC) ----------
rule "Camera (UVC)"
if [[ "$has_bison_cam" == "yes" ]]; then
  have CONFIG_MEDIA_SUPPORT     || add_fix CONFIG_MEDIA_SUPPORT y
  have CONFIG_VIDEO_V4L2        || add_fix CONFIG_VIDEO_V4L2 y
  have CONFIG_USB_VIDEO_CLASS   || add_fix CONFIG_USB_VIDEO_CLASS y
  have CONFIG_UVCVIDEO          || add_fix CONFIG_UVCVIDEO m
  # Videobuf helpers often get dropped in pruning; reassert
  have CONFIG_VIDEOBUF2_CORE    || add_fix CONFIG_VIDEOBUF2_CORE m
  have CONFIG_VIDEOBUF2_V4L2    || add_fix CONFIG_VIDEOBUF2_V4L2 m
  have CONFIG_VIDEOBUF2_MEMOPS  || add_fix CONFIG_VIDEOBUF2_MEMOPS m
fi

# ---------- Wi-Fi ----------
rule "Wi-Fi"
if [[ "$has_intel_wifi" == "yes" || "$lsmod_out" =~ (^|[[:space:]])iwlwifi([[:space:]]|$) ]]; then
  have CONFIG_WLAN              || add_fix CONFIG_WLAN y
  have CONFIG_CFG80211          || add_fix CONFIG_CFG80211 m
  have CONFIG_MAC80211          || add_fix CONFIG_MAC80211 m
  have CONFIG_WLAN_VENDOR_INTEL || add_fix CONFIG_WLAN_VENDOR_INTEL y
  have CONFIG_IWLWIFI           || add_fix CONFIG_IWLWIFI m
fi

# ---------- Bluetooth ----------
rule "Bluetooth"
# Even if no BT dongle shown, keep core small BT bits for peripherals
have CONFIG_BT           || add_fix CONFIG_BT m
have CONFIG_BT_HCIBTUSB  || add_fix CONFIG_BT_HCIBTUSB m
have CONFIG_BT_INTEL     || add_fix CONFIG_BT_INTEL m
# Common vendor helpers (harmless, small); conditional add based on lsmod
grep -q '^btbcm\>' <<<"$lsmod_out" && have CONFIG_BT_BCM  || add_fix CONFIG_BT_BCM m
grep -q '^btrtl\>'  <<<"$lsmod_out" && have CONFIG_BT_RTL  || add_fix CONFIG_BT_RTL m

# ---------- GPU / Display ----------
rule "GPU / Display"
have CONFIG_DRM                 || add_fix CONFIG_DRM y
have CONFIG_DRM_KMS_HELPER      || add_fix CONFIG_DRM_KMS_HELPER y
have CONFIG_DRM_FBDEV_EMULATION || add_fix CONFIG_DRM_FBDEV_EMULATION y
have CONFIG_DRM_I915            || add_fix CONFIG_DRM_I915 m
off CONFIG_DRM_NOUVEAU || log "WARN: nouveau not disabled (OK if intentional)"

# ---------- Audio ----------
rule "Audio"
have CONFIG_SND_HDA_INTEL         || add_fix CONFIG_SND_HDA_INTEL m
have CONFIG_SND_HDA_CODEC_REALTEK || add_fix CONFIG_SND_HDA_CODEC_REALTEK m
have CONFIG_SND_HDA_CODEC_HDMI    || add_fix CONFIG_SND_HDA_CODEC_HDMI m

# ---------- Realtek RTSX card reader ----------
rule "Realtek RTSX card reader"
if [[ "$has_rtsx" == "yes" || "$lsmod_out" =~ (^|[[:space:]])rtsx_pci([[:space:]]|$) ]]; then
  have CONFIG_MFD_RTSX_PCI     || add_fix CONFIG_MFD_RTSX_PCI m
  have CONFIG_MMC_REALTEK_PCI  || add_fix CONFIG_MMC_REALTEK_PCI m
fi

# ---------- Power / ACPI / ThinkPad ----------
rule "Power / ACPI / ThinkPad"
have CONFIG_ACPI           || add_fix CONFIG_ACPI y
have CONFIG_THINKPAD_ACPI  || add_fix CONFIG_THINKPAD_ACPI m

# ---------- Virtualization (optional) ----------
rule "Virtualization (optional)"
have CONFIG_KVM        || log "HINT: enable CONFIG_KVM if you use VMs"
have CONFIG_KVM_INTEL  || log "HINT: enable CONFIG_KVM_INTEL for Intel VT-x"

# ---------- Build-time sanity (speed) ----------
rule "Build-time sanity"
if have CONFIG_DEBUG_INFO || have CONFIG_DEBUG_INFO_BTF; then
  log "WARN: DEBUG_INFO or DEBUG_INFO_BTF enabled -> heavy compile/link"
  add_fix CONFIG_DEBUG_INFO n
  add_fix CONFIG_DEBUG_INFO_BTF n
fi

log ""
if [[ -s "$FIX" ]]; then
  log "Proposed fixes written to: $FIX"
  log "Apply with:"
  log "  cd ~/build/kernel/linux-zen/src/linux-*"
  log "  ./scripts/kconfig/merge_config.sh -m .config $FIX"
  log "  make olddefconfig"
else
  log "No fixes suggested. Your config covers all audited essentials."
fi
echo "Done. See $OUT"

