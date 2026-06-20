#!/usr/bin/env bash
# BagIdea Office — Linux (Ubuntu/Debian) one-shot installer & build.
#   • installs dependencies via apt (Node 20, Rust, WebKitGTK, X11 tools, audio)
#   • downloads Godot 4.6.3 (linux x86_64) if missing
#   • builds the native shell (tao/wry)
#   • wires Claude Code hooks and sets up the 'bagidea' CLI + autostart
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "  ==========================================="
echo "   BagIdea Office - LINUX INSTALLER (apt)"
echo "  ==========================================="

# ---- 1. Dependencies (apt) ---------------------------------------------------
echo "[1/6] installing dependencies (sudo apt)..."
if ! command -v apt-get &> /dev/null; then
  echo "    ! This installer targets Ubuntu/Debian (apt). On other distros, install the"
  echo "      equivalents of: nodejs(>=18) rust git webkit2gtk gtk3 libsoup3 x11-utils"
  echo "      wmctrl xdotool pulseaudio-utils  — then run: cargo build --release in shell/"
  exit 1
fi
sudo apt-get update -y
# Build + runtime libs for the Rust shell (tao/wry → WebKitGTK) + wallpaper/audio tools.
# WebKitGTK is 4.1 on newer Ubuntu, 4.0 on older — install whichever is available.
sudo apt-get install -y curl git build-essential pkg-config \
  libgtk-3-dev libwebkit2gtk-4.1-dev libsoup-3.0-dev \
  x11-utils wmctrl xdotool libxdo3 \
  pulseaudio-utils alsa-utils unzip \
  || sudo apt-get install -y curl git build-essential pkg-config \
       libgtk-3-dev libwebkit2gtk-4.0-dev libsoup2.4-dev \
       x11-utils wmctrl xdotool libxdo3 pulseaudio-utils alsa-utils unzip

# Node.js >= 18 (the daemon uses global fetch / AbortSignal.timeout). Ubuntu's apt node
# is often too old, so fall back to NodeSource 20 when needed.
need_node=1
if command -v node &> /dev/null; then
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  [ "$major" -ge 18 ] 2>/dev/null && need_node=0
fi
if [ "$need_node" -eq 1 ]; then
  echo "    + installing Node.js 20 (NodeSource)..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Rust (official rustup — the apt 'rustc' can be too old for some crates).
if ! command -v cargo &> /dev/null; then
  echo "    + installing Rust (rustup)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env" 2>/dev/null || true

# ---- 2. Godot ----------------------------------------------------------------
GODOT_DIR="$ROOT/godot/bin-linux"
GODOT_BIN="$GODOT_DIR/godot"
echo "[2/6] checking Godot engine..."
if [ ! -x "$GODOT_BIN" ]; then
  echo "    + downloading Godot 4.6.3 (linux x86_64) — ~80 MB, a progress bar follows..."
  mkdir -p "$GODOT_DIR"
  ZIP="$ROOT/godot/godot_linux.zip"
  curl -L --progress-bar "https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip" -o "$ZIP"
  unzip -q -o "$ZIP" -d "$GODOT_DIR"
  # The zip contains Godot_v4.6.3-stable_linux.x86_64 — normalize the name to 'godot'.
  mv "$GODOT_DIR"/Godot_v*_linux.x86_64 "$GODOT_BIN"
  chmod +x "$GODOT_BIN"
  rm -f "$ZIP"
  echo "    → installed Godot to $GODOT_BIN"
else
  echo "    - Godot already present"
fi

# ---- 3. Build the shell ------------------------------------------------------
echo "[3/6] building the native shell (first build takes several minutes — NOT frozen)..."
( cd "$ROOT/shell" && cargo build --release )

# ---- 4. Claude Code hooks (Node — same as macOS) -----------------------------
echo "[4/6] wiring Claude Code hooks..."
bash "$ROOT/installer/wire-hooks.sh" "$ROOT"

# ---- 5. CLI on PATH ----------------------------------------------------------
echo "[5/6] setting up the 'bagidea' command..."
chmod +x "$ROOT/cli/bagidea"
mkdir -p "$HOME/.local/bin"
ln -sf "$ROOT/cli/bagidea" "$HOME/.local/bin/bagidea"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" ;;
esac

# ---- 6. Autostart at login (XDG) — on by default, toggle with 'bagidea startup off' ----
echo "[6/6] enabling autostart at login..."
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/bagidea-office.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=BagIdea Office
Exec=$ROOT/shell/target/release/bagidea-office-shell
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK

echo "  ==========================================="
echo "   INSTALL COMPLETE!"
echo "  ==========================================="
echo ""
echo "  Open a NEW terminal (so PATH updates), then:  bagidea start"
echo "  (X11/Xorg sessions get the desktop-wallpaper look; on Wayland it runs as a"
echo "   fullscreen window pinned below other windows.)"
echo ""
