#!/usr/bin/env bash
# noesis_build_zen_pkg.sh — Arch-only, makepkg-based rebuild of linux-zen using your custom config
# Flow:
#   clean src/pkg → makepkg -o → pick src/linux-* →
#   (optional) localmodconfig → enforce minimal UVC chain (symbol-aware; gates only if needed) →
#   merge ~/Documents/noesis-hardware.config → olddefconfig →
#   re-assert minimal UVC chain (post-merge) → olddefconfig →
#   sanity (non-fatal; y|m; symbol-aware) → copy .config up →
#   updpkgsums → (FINAL) clean src and old packages → makepkg -sri

set -Eeuo pipefail
trap 'rc=$?; echo "ERROR line $LINENO: ${BASH_COMMAND:-?} (exit $rc)" >&2; exit $rc' ERR

PKGDIR="${HOME}/build/kernel/linux-zen"
BASECFG="${PKGDIR}/config"                          # PKGBUILD seed config
FRAG_HW="${HOME}/Documents/noesis-hardware.config"  # your fragment
MODPROBED="${HOME}/.config/modprobed.db"            # optional

ask()  { read -rp "==> $1 [y/N]: " _a; [[ $_a =~ ^[Yy]$ ]]; }
need() { command -v "$1" >/dev/null || { echo "Missing tool: $1"; exit 1; }; }

echo "==> Preflight checks"
need makepkg; need awk; need sed; need find; need sort
[[ -d "$PKGDIR" ]] || { echo "PKGDIR not found: $PKGDIR"; exit 1; }
[[ -f "$BASECFG" ]] || { echo "Base config not found: $BASECFG"; exit 1; }
[[ -f "$FRAG_HW" ]] || { echo "Hardware fragment missing: $FRAG_HW"; exit 1; }

cd "$PKGDIR"
echo "==> PWD: $(pwd)"

if ask "Remove src/ and pkg/ now to start clean?"; then
  echo "rm -rf src pkg"
  rm -rf src pkg
fi

echo "==> Extract sources (makepkg -o)"
makepkg -o

echo "==> Select kernel source directory"
mapfile -t KDIRS < <(find src -maxdepth 1 -type d -name 'linux-*' -printf '%f\n' | sort -V)
[[ ${#KDIRS[@]} -ge 1 ]] || { echo "No src/linux-* found"; exit 1; }
if (( ${#KDIRS[@]} == 1 )); then
  KSRCDIR="src/${KDIRS[0]}"
else
  echo "Multiple source dirs:"; i=1; for d in "${KDIRS[@]}"; do echo "  $i) $d"; ((i++)); done
  read -rp "Choose [1-${#KDIRS[@]}] (default ${#KDIRS[@]} = newest): " CHOICE
  [[ -z "$CHOICE" ]] && CHOICE=${#KDIRS[@]}
  [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE>=1 && CHOICE<=${#KDIRS[@]} )) || { echo "Invalid choice"; exit 1; }
  KSRCDIR="src/${KDIRS[$((CHOICE-1))]}"
fi
cd "$KSRCDIR"
echo "==> PWD: $(pwd)"

echo "==> Seed .config from PKGBUILD base (../../config)"
cp -f ../../config .config

if ask "Tighten with localmodconfig using ${MODPROBED}?"; then
  if [[ -f "$MODPROBED" ]]; then
    echo "make LSMOD=\"$MODPROBED\" localmodconfig"
    make LSMOD="$MODPROBED" localmodconfig || true
  else
    echo "(skip) ${MODPROBED} not found."
  fi
fi

# ---- helpers for symbol-aware enabling ----
ksym_exists() { scripts/config -s "$1" >/dev/null 2>&1; }
enable_y()    { if ksym_exists "$1"; then echo "scripts/config --enable $1"; scripts/config --enable "$1"; fi; }
enable_m()    { if ksym_exists "$1"; then echo "scripts/config --module $1"; scripts/config --module "$1"; fi; }

echo "==> Enforce minimal UVC chain via scripts/config (pre-merge)"
[[ -x scripts/config ]] || { echo "scripts/config not found"; exit 1; }

# Minimal USB/V4L2 + UVC (conditionally, only if these symbols exist)
enable_y CONFIG_USB_SUPPORT
enable_y CONFIG_USB
enable_y CONFIG_USB_XHCI_HCD
enable_y CONFIG_USB_XHCI_PCI

enable_y CONFIG_MEDIA_SUPPORT
enable_y CONFIG_VIDEO_DEV
enable_y CONFIG_VIDEO_V4L2   # may not exist on some trees

enable_m CONFIG_USB_VIDEO_CLASS
enable_m CONFIG_UVCVIDEO

echo "==> make olddefconfig (resolve newly unlocked symbols)"
make olddefconfig

if ! grep -Eq '^CONFIG_UVCVIDEO=(y|m)' .config; then
  echo "==> UVC not set; enabling media filter gates if present"
  for gate in CONFIG_MEDIA_SUPPORT_FILTER CONFIG_MEDIA_USB_SUPPORT CONFIG_MEDIA_CAMERA_SUPPORT CONFIG_MEDIA_CONTROLLER; do
    if ksym_exists "${gate}"; then
      echo "scripts/config --enable ${gate}"
      scripts/config --enable "${gate}" || true
    fi
  done
  echo "==> make olddefconfig (after gates)"
  make olddefconfig
fi

echo "==> Merge hardware fragment (post-UVC): $FRAG_HW"
[[ -x scripts/kconfig/merge_config.sh ]] || { echo "missing scripts/kconfig/merge_config.sh"; exit 1; }
echo "./scripts/kconfig/merge_config.sh -m .config \"$FRAG_HW\""
./scripts/kconfig/merge_config.sh -m .config "$FRAG_HW"

echo "==> make olddefconfig (post-merge)"
make olddefconfig

echo "==> Re-assert minimal UVC chain (fragment may have flipped some)"
enable_y CONFIG_USB_SUPPORT
enable_y CONFIG_USB
enable_y CONFIG_USB_XHCI_HCD
enable_y CONFIG_USB_XHCI_PCI

enable_y CONFIG_MEDIA_SUPPORT
enable_y CONFIG_VIDEO_DEV
enable_y CONFIG_VIDEO_V4L2   # if it exists

# Keep class + UVC as modules for flexibility
enable_m CONFIG_USB_VIDEO_CLASS
enable_m CONFIG_UVCVIDEO

# If still not selected, open gates if present
if ! grep -Eq '^CONFIG_UVCVIDEO=(y|m)' .config; then
  for gate in CONFIG_MEDIA_SUPPORT_FILTER CONFIG_MEDIA_USB_SUPPORT CONFIG_MEDIA_CAMERA_SUPPORT CONFIG_MEDIA_CONTROLLER; do
    if ksym_exists "${gate}"; then
      echo "scripts/config --enable ${gate}"
      scripts/config --enable "${gate}" || true
    fi
  done
fi

echo "==> make olddefconfig (post-merge enforcement)"
make olddefconfig

echo "==> Sanity check (non-fatal; accept y|m; only require symbols that exist)"
sym_set() { grep -Eq "^$1=(y|m)" .config; }
need_if_exists() {
  local s="$1"
  if scripts/config -s "$s" >/dev/null 2>&1; then
    if sym_set "$s"; then
      :
    else
      echo "ERROR: $s not set (needs y or m)  <-- continuing"
    fi
  fi
}

# Must-have chain for webcam (guard by existence) — VIDEO_V4L2 optional
for sym in \
  CONFIG_USB_SUPPORT CONFIG_USB CONFIG_USB_XHCI_HCD CONFIG_USB_XHCI_PCI \
  CONFIG_MEDIA_SUPPORT CONFIG_VIDEO_DEV \
  CONFIG_USB_VIDEO_CLASS CONFIG_UVCVIDEO
do
  need_if_exists "$sym"
done
echo "Sanity complete (UVC chain checked; VIDEO_V4L2 optional)."

warn_if_missing() {
  local s="$1"
  if scripts/config -s "$s" >/dev/null 2>&1 && ! sym_set "$s"; then
    echo "WARN: $s not set"
  fi
}
for sym in \
  CONFIG_EXT4_FS \
  CONFIG_BLK_DEV_NVME CONFIG_NVME_CORE \
  CONFIG_VFAT_FS CONFIG_FAT_FS CONFIG_EXFAT_FS CONFIG_NTFS3_FS \
  CONFIG_CFG80211 CONFIG_BT CONFIG_BT_HCIBTUSB CONFIG_IWLWIFI \
  CONFIG_SND_HDA_INTEL
do
  warn_if_missing "$sym"
done

echo "==> Persist final .config → ${BASECFG}"
cp -f .config ../../config

cd ../..
echo "==> PWD: $(pwd)"
echo "==> Updating checksums (updpkgsums)"
updpkgsums

# ---------------------- FINAL REBUILD PHASE ----------------------
echo "==> Final rebuild: remove src/ to re-run prepare(), and optionally remove old packages"
if ask "Remove src/ now so prepare() runs on next build?"; then
  echo "rm -rf src"
  rm -rf src
fi
if ask "Remove existing *.pkg.tar.* to avoid 'already built' message?"; then
  echo "rm -f ./*.pkg.tar.*"
  rm -f ./*.pkg.tar.*
fi

echo "==> Building & installing (makepkg -sri) — this will re-extract sources and run prepare()"
echo "This will compile and install linux-zen with your config."
if ask "Proceed?"; then
  makepkg -sri
else
  echo "Stopped before build."
  exit 0
fi
# ---------------------------------------------------------------

echo "==> Done. Verify with: pacman -Q linux-zen && uname -r ; reboot when ready."

