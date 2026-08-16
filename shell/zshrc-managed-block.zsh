if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

export CLICOLOR=1

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons=auto"
  alias ll="eza -lah --icons=auto --git"
  alias tree="eza --tree --icons=auto"
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if [[ -f "$(brew --prefix 2>/dev/null)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6e6a86"

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if [[ -f "$(brew --prefix 2>/dev/null)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Recent directories: a deduplicated, most-recently-visited-first stack,
# tracked ourselves via a chpwd hook rather than reusing zoxide -- zoxide
# blends frequency and recency into one opaque score with no CLI flag to
# get pure last-visited order back out. $HOME itself is excluded since new
# WezTerm tabs already start there (not a "visit" worth tracking); this
# also feeds the WezTerm welcome banner's numbered directory list.
typeset -g RECENT_DIRS_FILE="$HOME/.cache/zsh/recent-dirs"
typeset -gi RECENT_DIRS_MAX=15

_track_recent_dir() {
  [[ "$PWD" == "$HOME" ]] && return
  mkdir -p "${RECENT_DIRS_FILE:h}"
  local -a dirs
  [[ -f "$RECENT_DIRS_FILE" ]] && dirs=("${(@f)$(<"$RECENT_DIRS_FILE")}")
  dirs=("$PWD" "${(@)dirs:#$PWD}")
  (( ${#dirs[@]} > RECENT_DIRS_MAX )) && dirs=("${(@)dirs[1,RECENT_DIRS_MAX]}")
  print -l -- "${dirs[@]}" >| "$RECENT_DIRS_FILE"
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _track_recent_dir

# `j` with no argument lists the recent-directories stack (also shown,
# numbered, in the WezTerm welcome banner); `j <n>` jumps to entry n.
j() {
  local -a dirs
  [[ -f "$RECENT_DIRS_FILE" ]] && dirs=("${(@f)$(<"$RECENT_DIRS_FILE")}")
  if [[ -z "$1" ]]; then
    local i
    for (( i = 1; i <= ${#dirs[@]}; i++ )); do
      printf '%2d  %s\n' "$i" "${dirs[i]}"
    done
    return 0
  fi
  if [[ -z "${dirs[$1]}" ]]; then
    echo "j: no entry $1 (run 'j' with no argument to list)" >&2
    return 1
  fi
  cd -- "${dirs[$1]}"
}

# `jj` fuzzy-picks from the same recent-directories stack via fzf, for when
# you don't remember (or don't want to count) the number `j` would need.
if command -v fzf >/dev/null 2>&1; then
  jj() {
    local -a dirs
    [[ -f "$RECENT_DIRS_FILE" ]] && dirs=("${(@f)$(<"$RECENT_DIRS_FILE")}")
    if (( ${#dirs[@]} == 0 )); then
      echo "jj: no recent directories tracked yet" >&2
      return 1
    fi
    local pick
    pick=$(printf '%s\n' "${dirs[@]}" | fzf --prompt='jump to > ' --height=40% --reverse) || return 1
    [[ -n "$pick" ]] && cd -- "$pick"
  }
fi

if [[ -f "$HOME/.config/wezterm/welcome.zsh" ]]; then
  source "$HOME/.config/wezterm/welcome.zsh"
fi
