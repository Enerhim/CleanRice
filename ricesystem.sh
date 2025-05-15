#!/usr/bin/env bash
# ricesystem.sh
# Automate Arch Linux + Hyprland ricing with provided configs

set -euo pipefail
IFS=$'\n\t'

# Variables
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_dir="$HOME/config_backup_$timestamp"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_shell_rc="$HOME/.bashrc"  # Adjust if using zsh: ~/.zshrc

# Package list for pacman
pacman_pkgs=(
  hyprland hyprlock hyprpaper kitty waybar networkmanager network-manager-applet
  thunar nano git base-devel rofi rsync ttf-dejavu ttf-liberation ttf-font-awesome
  noto-fonts noto-fonts-cjk ttf-jetbrains-mono-nerd noto-fonts-emoji nwg-look
  sddm fastfetch cava btop firefox
)

# Function: Ensure running as root
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
  fi
}

# Function: Install pacman packages
install_pacman_pkgs() {
  echo "[*] Updating system and installing packages via pacman..."
  pacman -Syu --noconfirm "${pacman_pkgs[@]}"
}

# Function: Install AUR helper yay
install_yay() {
  if ! command -v yay &>/dev/null; then
    echo "[*] Installing yay from AUR..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    pushd /tmp/yay >/dev/null
    makepkg -si --noconfirm
    popd >/dev/null
    rm -rf /tmp/yay
  else
    echo "[*] yay already installed. Skipping."
  fi
}

# Function: Backup and replace configs
backup_and_deploy_configs() {
  echo "[*] Backing up existing config directories to $backup_dir"
  mkdir -p "$backup_dir"
  for dir in rofi waybar hypr fastfetch dunst; do
    if [[ -d "$HOME/.config/$dir" ]]; then
      mv "$HOME/.config/$dir" "$backup_dir/"
    fi
    cp -r "$repo_dir/$dir" "$HOME/.config/"
  done
}

# Function: Install themes via yay
install_aur_themes() {
  echo "[*] Installing papirus-icon-theme and sddm-theme-corners-git via yay..."
  yay -S --noconfirm papirus-icon-theme sddm-theme-corners-git
}

# Function: Configure display manager
configure_sddm() {
  echo "[*] Disabling any current display manager and enabling sddm..."
  # Attempt to detect common DMs and disable
  for svc in gdm lxdm lightdm sddm; do
    if systemctl is-enabled "$svc" &>/dev/null; then
      systemctl disable "$svc" --now || true
    fi
  done
  systemctl enable sddm --now

  echo "[*] Setting SDDM theme to 'corners'"
  mkdir -p /etc/sddm.conf.d
  cat > /etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=corners
EOF
}

# Function: Deploy wallpaper binary and images
deploy_wallpaper() {
  echo "[*] Deploying wallpaper binary and images..."
  install -Dm755 "$repo_dir/wallpaper" /usr/local/bin/wallpaper
}

# Function: Configure fastfetch at shell startup
configure_fastfetch() {
  echo "[*] Adding fastfetch invocation to user shell rc: $user_shell_rc"
  fastfetch_line="fastfetch --logo $HOME/.config/fastfetch/makima_edit.png --logo-width 30"
  if ! grep -Fxq "$fastfetch_line" "$user_shell_rc"; then
    echo -e "\n# Invoke fastfetch on login" >> "$user_shell_rc"
    echo "$fastfetch_line" >> "$user_shell_rc"
  else
    echo "[*] fastfetch invocation already present in $user_shell_rc"
  fi
}

# Main workflow
main() {
  require_root
  install_pacman_pkgs
  install_yay
  backup_and_deploy_configs
  install_aur_themes
  configure_sddm
  deploy_wallpaper
  configure_fastfetch

  echo "[*] Ricing complete. Enjoy your new Arch + Hyprland setup!"
}

main "$@"
