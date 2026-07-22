#!/usr/bin/env bash
#
# End-to-end installer: Zsh + Oh My Zsh + plugins + Starship prompt.
#
# Usage:
#   ./install.sh
#   curl -fsSL <raw-url-to-this-script> | bash
#
# Safe to re-run: every step checks whether it already applied itself.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
STARSHIP_INSTALL_URL="https://starship.rs/install.sh"
STARSHIP_CONFIG_URL="https://gist.githubusercontent.com/rifkhan107/a49706cb2e69ac0e467a585278a23d99/raw/666e5238c043a6eba8406715b36bbf70ddd9f912/ubuntu-starship.toml"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSHRC="$HOME/.zshrc"
STARSHIP_CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLED_STARSHIP_CONFIG="$SCRIPT_DIR/configs/starship.toml"

PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)
declare -A PLUGIN_REPOS=(
  [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
  [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

SKIP_CHSH="${SKIP_CHSH:-false}"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

c_reset='\033[0m'; c_green='\033[0;32m'; c_yellow='\033[0;33m'; c_red='\033[0;31m'; c_blue='\033[0;34m'

log()  { printf "${c_blue}==>${c_reset} %s\n" "$1"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$1"; }
warn() { printf "${c_yellow}  !${c_reset} %s\n" "$1"; }
err()  { printf "${c_red}  ✗ %s${c_reset}\n" "$1" >&2; }

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "Need root privileges to run: $* (no sudo found)"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Package manager detection
# ---------------------------------------------------------------------------

PKG_MANAGER=""

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then PKG_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then PKG_MANAGER="zypper"
  elif command -v apk >/dev/null 2>&1; then PKG_MANAGER="apk"
  elif command -v brew >/dev/null 2>&1; then PKG_MANAGER="brew"
  else
    err "No supported package manager found (apt, dnf, yum, pacman, zypper, apk, brew)."
    exit 1
  fi
  ok "Detected package manager: $PKG_MANAGER"
}

install_packages() {
  local pkgs=("$@")
  case "$PKG_MANAGER" in
    apt)
      run_as_root apt-get update -y
      run_as_root apt-get install -y "${pkgs[@]}"
      ;;
    dnf)    run_as_root dnf install -y "${pkgs[@]}" ;;
    yum)    run_as_root yum install -y "${pkgs[@]}" ;;
    pacman) run_as_root pacman -Sy --noconfirm "${pkgs[@]}" ;;
    zypper) run_as_root zypper install -y "${pkgs[@]}" ;;
    apk)    run_as_root apk add "${pkgs[@]}" ;;
    brew)   brew install "${pkgs[@]}" ;;
  esac
}

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

ensure_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    log "curl not found, installing it"
    install_packages curl
    ok "curl installed"
  fi
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    ok "zsh already installed ($(zsh --version))"
    return
  fi
  log "Installing zsh"
  install_packages zsh
  ok "zsh installed ($(zsh --version))"
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "Oh My Zsh already installed"
    return
  fi
  log "Installing Oh My Zsh (unattended)"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "$OMZ_INSTALL_URL")" "" --unattended
  ok "Oh My Zsh installed"
}

install_plugin() {
  local name="$1" repo="${PLUGIN_REPOS[$1]}"
  local dest="$ZSH_CUSTOM/plugins/$name"
  if [ -d "$dest" ]; then
    ok "Plugin already installed: $name"
    return
  fi
  log "Installing plugin: $name"
  git clone --depth 1 "$repo" "$dest"
  ok "Plugin installed: $name"
}

configure_plugins() {
  [ -f "$ZSHRC" ] || { warn "$ZSHRC not found, skipping plugin configuration"; return; }

  local desired="plugins=(git ${PLUGINS[*]})"

  if grep -qE '^\s*plugins=\(' "$ZSHRC"; then
    if grep -qF "$desired" "$ZSHRC"; then
      ok "Plugins already configured in .zshrc"
      return
    fi
    cp "$ZSHRC" "$ZSHRC.bak.$(date +%s)"
    sed -i.tmp -E "s/^\s*plugins=\([^)]*\)/${desired}/" "$ZSHRC" && rm -f "$ZSHRC.tmp"
    ok "Updated plugins line in .zshrc (backup saved)"
  else
    printf '\n%s\n' "$desired" >> "$ZSHRC"
    ok "Appended plugins line to .zshrc"
  fi
}

configure_ls_colors() {
  [ -f "$ZSHRC" ] || { warn "$ZSHRC not found, skipping LS_COLORS configuration"; return; }

  # Default LS_COLORS renders world-writable dirs (chmod 777) as blue-on-green
  # (ow/tw codes), which is hard to read on dark themes. Override to plain bold blue.
  if grep -qF 'LS_COLORS="$LS_COLORS:ow=01;34:tw=01;34"' "$ZSHRC"; then
    ok "LS_COLORS override already present in .zshrc"
    return
  fi
  {
    printf '\n# Readable colors for world-writable directories (default ow/tw is blue-on-green)\n'
    printf 'export LS_COLORS="$LS_COLORS:ow=01;34:tw=01;34"\n'
  } >> "$ZSHRC"
  ok "Added LS_COLORS override to .zshrc"
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    ok "Starship already installed ($(starship --version | head -n1))"
    return
  fi
  log "Installing Starship"
  curl -fsSL "$STARSHIP_INSTALL_URL" | sh -s -- --yes
  ok "Starship installed"
}

configure_starship_init() {
  [ -f "$ZSHRC" ] || { warn "$ZSHRC not found, skipping starship init"; return; }

  if grep -qF 'starship init zsh' "$ZSHRC"; then
    ok "Starship init already present in .zshrc"
    return
  fi
  {
    printf '\n# Starship prompt\n'
    printf 'eval "$(starship init zsh)"\n'
  } >> "$ZSHRC"
  ok "Added Starship init to .zshrc"
}

configure_starship_config() {
  mkdir -p "$STARSHIP_CONFIG_DIR"

  log "Fetching your Starship config from gist"
  local tmp_file
  tmp_file="$(mktemp)"

  if curl -fsSL "$STARSHIP_CONFIG_URL" -o "$tmp_file"; then
    ok "Downloaded latest config from gist"
  elif [ -f "$BUNDLED_STARSHIP_CONFIG" ]; then
    warn "Could not reach gist (network error), using bundled fallback config"
    cp "$BUNDLED_STARSHIP_CONFIG" "$tmp_file"
  else
    rm -f "$tmp_file"
    warn "Could not download custom Starship config, and no bundled fallback found."
    warn "Leaving existing config (if any) untouched; Starship will use its defaults otherwise."
    return
  fi

  if [ -f "$STARSHIP_CONFIG_FILE" ] && ! cmp -s "$tmp_file" "$STARSHIP_CONFIG_FILE"; then
    cp "$STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_FILE.bak.$(date +%s)"
    warn "Existing starship.toml backed up"
  fi
  mv "$tmp_file" "$STARSHIP_CONFIG_FILE"
  ok "Starship config written to $STARSHIP_CONFIG_FILE"
}

set_default_shell() {
  if [ "$SKIP_CHSH" = "true" ]; then
    warn "SKIP_CHSH=true, not changing default shell"
    return
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "zsh is already the default shell"
    return
  fi

  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    log "Registering $zsh_path in /etc/shells"
    run_as_root sh -c "echo '$zsh_path' >> /etc/shells"
  fi

  log "Changing default shell to zsh (you may be prompted for your password)"
  if chsh -s "$zsh_path"; then
    ok "Default shell changed to zsh. Log out and back in for it to take effect."
  else
    warn "Could not change default shell automatically. Run manually: chsh -s $zsh_path"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "Starting Zsh + Oh My Zsh + Starship setup"

  detect_pkg_manager
  ensure_curl
  install_zsh
  install_oh_my_zsh

  for plugin in "${PLUGINS[@]}"; do
    install_plugin "$plugin"
  done
  configure_plugins
  configure_ls_colors

  install_starship
  configure_starship_config
  configure_starship_init

  set_default_shell

  echo
  ok "All done!"
  echo "Restart your terminal or run: exec zsh"
}

main "$@"
