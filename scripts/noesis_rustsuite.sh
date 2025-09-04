#!/usr/bin/env bash
# Arch Linux only — rustup install → (optional) source-build Rust into ~/.local/opt/rust-<ref>
set -Eeuo pipefail
trap 'rc=$?; echo "ERROR line $LINENO: ${BASH_COMMAND:-?} (exit $rc)" >&2; exit $rc' ERR

JOBS="$(nproc)"
SHELL_RC="${SHELL_RC:-$HOME/.bashrc}"      # set to ~/.zshrc if you use zsh
BIN_DIR="$HOME/.local/bin"
OPT_ROOT="$HOME/.local/opt"
WORKDIR="$HOME/build"
RUST_DIR="$WORKDIR/rust"
RUSTUP_BIN="$HOME/.cargo/bin/rustup"

info(){ printf "\n==> %s\n" "$*"; }
note(){ printf "    - %s\n" "$*"; }
ask(){ read -r -p "$1 [y/N]: " a; [[ "$a" =~ ^[Yy]$ ]]; }
ensure_path(){ local p="$1"; grep -qF "$p" "$SHELL_RC" 2>/dev/null || echo "export PATH=\"$p:\$PATH\"" >> "$SHELL_RC"; }

# 0) Prep dirs & PATH
mkdir -p "$BIN_DIR" "$OPT_ROOT" "$WORKDIR"
export PATH="$HOME/.cargo/bin:$BIN_DIR:$PATH"
ensure_path "$HOME/.cargo/bin"
ensure_path "$BIN_DIR"

# 1) rustup (official)
info "Install rustup (official method)"
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
else
  note "rustup already installed; running self update"
  rustup self update || true
fi
"$RUSTUP_BIN" --version >/dev/null

# 2) Optional components
if ask "Add components to current toolchain (clippy, rustfmt, rust-src)?"; then
  "$RUSTUP_BIN" component add clippy rustfmt rust-src || note "Some components may be unavailable for this toolchain"
fi

# 3) Optional source build
if ask "Build Rust from source (Skylake + clang/lld + ThinLTO) into ~/.local/opt/rust-<ref>?"; then
  sudo pacman -S --needed base-devel git clang lld cmake python llvm curl

  # choose ref
  read -r -p "Enter a Rust git ref (e.g., 1.89.0) or press Enter for default (master): " RUST_REF
  TOOLCHAIN_NAME="${RUST_REF:+rust-$RUST_REF}"
  TOOLCHAIN_NAME="${TOOLCHAIN_NAME:-rust-stable-local}"
  PREFIX="$OPT_ROOT/$TOOLCHAIN_NAME"

  info "Workspace: $WORKDIR  |  Clone → $RUST_DIR  |  Install prefix → $PREFIX"
  rm -rf "$RUST_DIR"
  git clone https://github.com/rust-lang/rust.git "$RUST_DIR"
  cd "$RUST_DIR"
  if [[ -n "$RUST_REF" ]]; then
    git fetch --all --tags
    git checkout --detach "$RUST_REF"
  fi

  # config.toml (NO rustflags here; pass via env to x.py)
  cat > config.toml <<EOF
[build]
jobs = $JOBS
extended = true
tools = ["cargo","clippy","rustfmt"]

[target.x86_64-unknown-linux-gnu]
cc = "clang"
cxx = "clang++"
linker = "clang"

[install]
prefix = "$PREFIX"

[rust]
channel = "stable"
codegen-units-std = 1
debuginfo-level = 0
optimize = true
lto = "thin"
EOF

  info "Build (this will take a while)…"
  RUSTFLAGS="-C target-cpu=skylake -C link-arg=-fuse-ld=lld" ./x.py build

  info "Install to $PREFIX (no sudo needed)"
  RUSTFLAGS="-C target-cpu=skylake -C link-arg=-fuse-ld=lld" ./x.py install

  # Symlink convenience entrypoints into ~/.local/bin
  info "Symlink main binaries into $BIN_DIR"
  for b in rustc cargo rustdoc rust-gdb rust-lldb rls rustfmt clippy-driver; do
    [[ -x "$PREFIX/bin/$b" ]] && ln -sf "$PREFIX/bin/$b" "$BIN_DIR/$b"
  done

  # Link into rustup and set default
  info "Register toolchain with rustup as '$TOOLCHAIN_NAME'"
  "$RUSTUP_BIN" toolchain link "$TOOLCHAIN_NAME" "$PREFIX"
  "$RUSTUP_BIN" default "$TOOLCHAIN_NAME"
  note "You can switch back anytime:  rustup default stable"
else
  note "Skipping source build; rustup-managed toolchains are ready to use."
fi

# 4) Optional Cargo tuning (user-wide)
if ask "Write ~/.cargo/config.toml with Skylake + lld tuning? (overwrites if exists)"; then
  mkdir -p "$HOME/.cargo"
  cat > "$HOME/.cargo/config.toml" <<'EOF'
[build]
rustflags = [
  "-C", "target-cpu=skylake",
  "-C", "link-arg=-fuse-ld=lld"
]

[target.x86_64-unknown-linux-gnu]
# linker = "clang"   # uncomment to force clang driver globally

[profile.release]
opt-level = 3
codegen-units = 1
lto = "thin"
panic = "abort"
strip = true
incremental = false
debug = false
EOF
fi

# 5) Verify
info "Verification"
"$RUSTUP_BIN" show
command -v rustc >/dev/null && rustc -V || note "rustc on PATH depends on rustup default / symlinks"
echo -e "\nDone. Open a new shell or:  source \"$SHELL_RC\""

