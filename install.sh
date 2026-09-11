#!/usr/bin/env bash
# Fresh-machine bootstrap for Arch Linux. Idempotent: re-run any time.
# Style/flow lifted from https://github.com/akhilnarang/scripts, scoped down
# to one distro (Arch) since that's the only real target — see README.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# --- 1. packages -------------------------------------------------------------
sudo pacman -Syu --needed --noconfirm - < packages/pacman.txt

if ! command -v yay >/dev/null; then
  echo "yay not found, bootstrapping it..."
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  (cd /tmp/yay-bin && makepkg -si --noconfirm)
fi
yay -S --needed --noconfirm - < packages/aur.txt

# --- 2. oh-my-zsh: let its installer generate the stock .zshrc, then patch --
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# zsh-syntax-highlighting must be the LAST plugin sourced (its own docs say so)
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
sed -i 's/^plugins=(git)$/plugins=(git archlinux systemd zsh-autosuggestions fzf zsh-syntax-highlighting)/' "$HOME/.zshrc"

# clone commands as listed in each plugin's own INSTALL.md (Oh My Zsh section)
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# --- 3. ssh key + gnome-keyring ssh-agent (matches this machine) ------------
# gnome-keyring/gcr-4 are here as dependencies of other packages on this
# machine (not explicit), and the socket that wires SSH_AUTH_SOCK to it is a
# user-level enable, not a package default — both need doing explicitly.
systemctl --user enable --now gcr-ssh-agent.socket

if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  mkdir -p -m 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "faizauthar@gmail.com" -f "$HOME/.ssh/id_ed25519"
fi

cat <<'EOF'

SSH key ready. gcr-ssh-agent auto-discovers keys in ~/.ssh — no ssh-add
needed. First use (first git push / ssh) pops a GUI passphrase prompt with
an "automatically unlock" checkbox; tick it once and gnome-keyring unlocks
the key at every login after that (same as this machine, via PAM in
/etc/pam.d/gdm-password — shipped by the gdm package, nothing to script).
EOF

# --- 4. dotfiles symlinks ------------------------------------------------------
declare -A LINKS=(
  ["zsh/.zshenv"]="$HOME/.zshenv"
)
for src in "${!LINKS[@]}"; do
  dest="${LINKS[$src]}"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    echo "backed up existing $dest"
  fi
  ln -sfn "$(pwd)/$src" "$dest"
  echo "linked $src -> $dest"
done

# default shell -> zsh
[[ "$SHELL" == */zsh ]] || chsh -s "$(command -v zsh)"

# --- 5. hardware-specific setup ------------------------------------------------
./hardware/check-thinkpad-t14.sh || echo "hardware setup skipped/failed, see above"

echo "done."
