# oh-my-zsh stock template, checked in statically (this repo is the source
# of truth — no more generate-then-sed at install time). Everything else
# (env vars, PATH, options, aliases) lives in zsh/.zshenv since it's sourced
# for every zsh invocation; .zshrc only owns oh-my-zsh + theme + plugins.

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

# archlinux/systemd plugins are Linux-only; macos plugin is Darwin-only.
# zsh-syntax-highlighting must be LAST (its own docs require it).
if [[ "$(uname -s)" == Darwin ]]; then
  plugins=(git zsh-autosuggestions fzf macos zsh-syntax-highlighting)
else
  plugins=(git archlinux systemd zsh-autosuggestions fzf zsh-syntax-highlighting)
fi

source $ZSH/oh-my-zsh.sh
