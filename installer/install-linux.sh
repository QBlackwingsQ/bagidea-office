#!/usr/bin/env bash
# BagIdea Office - Linux (Ubuntu/Debian) Web Installer.
#
# Installs everything: Node 20 · Rust · Godot 4.6.3 · WebKitGTK + X11 tools,
# clones the repo to ~/BagIdeaOffice, builds the shell, wires hooks, sets up the
# `bagidea` command + autostart.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bagidea/bagidea-office/main/installer/install-linux.sh | bash

set -e

APP_DIR="$HOME/BagIdeaOffice"
REPO_URL="${BAGIDEA_REPO:-https://github.com/bagidea/bagidea-office.git}"
BRANCH="${BAGIDEA_BRANCH:-main}"

echo ""
echo "  ==========================================="
echo "   BagIdea Office - LINUX WEB INSTALLER"
echo "  ==========================================="
echo ""

if ! command -v git &> /dev/null; then
  echo "    + installing git..."
  sudo apt-get update -y && sudo apt-get install -y git
fi

if [ ! -d "$APP_DIR" ]; then
  echo "[1/2] Cloning repository to $APP_DIR..."
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  echo "[1/2] Repository already exists at $APP_DIR, updating..."
  cd "$APP_DIR" && git pull origin "$BRANCH"
fi

echo "[2/2] Launching internal build & setup..."
cd "$APP_DIR"
chmod +x build-linux.sh
./build-linux.sh

echo ""
echo "  Done! BagIdea Office is ready at $APP_DIR"
echo "  Open a new terminal and run:  bagidea start"
echo ""
