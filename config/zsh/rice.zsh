# Shell Catppuccin : zsh + starship (preset Catppuccin Powerline) + fastfetch
# Chargé depuis ~/.zshrc (l'installateur ajoute la ligne `source ~/.config/zsh/rice.zsh`).

export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# historique et complétion
HISTFILE="$HOME/.zsh_history"; HISTSIZE=50000; SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE AUTO_CD
autoload -Uz compinit && compinit -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# plugins (chemins Debian/Ubuntu puis Arch)
for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [ -r "$f" ] && source "$f" && break
done
for f in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
         /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [ -r "$f" ] && source "$f" && break
done

# couleurs Catppuccin Mocha pour l'autosuggestion
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'

command -v starship >/dev/null && eval "$(starship init zsh)"

# décommente pour afficher fastfetch à chaque nouveau terminal
# command -v fastfetch >/dev/null && fastfetch
