# ~/.zshrc — Linux (Fedora) adaptation of Scott's dotfiles zshrc.
#
# This is the CLEAN Linux port: same theme + plugins + functions you use on
# the Mac, with macOS-only bits translated or dropped:
#   pbcopy            -> wl-copy        (wl-clipboard)
#   terminal-notifier -> notify-send    (libnotify)
#   blueutil          -> bluetoothctl
#   /opt/homebrew/... -> Fedora paths   (/usr/share/...)
#   dscacheutil, java_home, conda, Python2.7/Cassandra/Android/dotnet PATHs -> removed
#
# Symlink this from the bootstrap repo (see dotfiles-symlinks.md), NOT the
# Mac zshrc. To unify both into one file later, wrap platform blocks in:
#   if [[ "$OSTYPE" == darwin* ]]; then ... elif [[ "$OSTYPE" == linux* ]]; then ... fi

# --- oh-my-zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"
ENABLE_CORRECTION="true"
plugins=(git colored-man-pages colorize rand-quote battery thefuck)
source "$ZSH/oh-my-zsh.sh"

autoload zmv
export RPROMPT="%D{%I:%M:%S}"

# --- login greeting (only if the tools are installed) ---
if command -v cowsay >/dev/null && command -v fortune >/dev/null && command -v lolcat >/dev/null; then
  cowsay -f "$(cowsay -l | tail -n +2 | tr ' ' '\n' | sort -R | head -n 1)" "$(fortune -s)" | lolcat
fi

# --- secrets / local-only keys (OpenAI, Anthropic, HF tokens, EDITOR, ...) ---
# Lives in your dotfiles repo and is gitignored. Adjust the path to wherever
# you cloned dotfiles on this machine.
[ -f "$HOME/dotfiles/.env" ] && source "$HOME/dotfiles/.env"
[ -f "$HOME/Documents/dotfiles/.env" ] && source "$HOME/Documents/dotfiles/.env"

# --- zsh autocorrect ---
unsetopt correct_all
setopt correct

# --- aliases ---
alias reload="source ~/.zshrc"
alias ccat="colorize"
alias please='sudo $(fc -ln -1)'
alias dc='docker compose'        # docker compose v2 plugin (was docker-compose on Mac)
alias cpwd="pwd | tr -d '\n' | wl-copy"   # was pbcopy
alias master='git co master'
alias recent_branches='git branch --sort=-committerdate'
alias gpl='git pull'
alias nuke_mk='kubectl delete --all pods --namespace=default && kubectl delete --all deployments --namespace=default && kubectl delete --all services'
alias chat='chatgpt'

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"            # Rust (if installed via rustup)
# Go
export GOPATH="$HOME/go-workspace"
export PATH="$GOPATH/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"           # if you install Go from go.dev
# npm global bin (when using a user-level npm prefix)
export PATH="$HOME/.npm-global/bin:$PATH"

# --- nvm (lazy-loaded; official installer puts it in ~/.nvm) ---
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
  unset -f nvm node npm npx _load_nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm "$@"; }
npx()  { _load_nvm; npx "$@"; }

# --- autojump (Fedora path) ---
[ -f /usr/share/autojump/autojump.zsh ] && source /usr/share/autojump/autojump.zsh

# --- fzf (Fedora installs bindings under /usr/share/fzf) ---
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
[ -f /usr/share/fzf/shell/completion.zsh ]   && source /usr/share/fzf/shell/completion.zsh

# --- thefuck ---
command -v thefuck >/dev/null && eval "$(thefuck --alias)"

# ===========================================================================
# Functions
# ===========================================================================

function remind() { history | grep "$1"; }

# sort a file in place
function sort!() { sort "$1" -o "$1"; }

function count_files() { find "$1" -type f | wc -l; }

function new_shell_script() {
  touch "$1"
  printf '#!/usr/bin/env bash\n\n' >> "$1"
  echo "set -euxo pipefail" >> "$1"
}

# Notify when a long-running task finishes (was terminal-notifier)
notify_done() { notify-send 'Terminal' 'Done with task!'; }

# Format PATH human-readable
function path() { echo "$PATH" | tr -s ':' '\n'; }

# Add RVM to PATH if present
[ -d "$HOME/.rvm/bin" ] && export PATH="$PATH:$HOME/.rvm/bin"

# git helper: branch, add, commit, PR (uses gh instead of hub on Linux)
function fast_c() {
  git checkout -b "scott.new-branch.$(date +"%Y-%m-%d-%s")"
  git add .
  git commit -m "$1"
  gh pr create --fill        # was: hub pull-request
}

function search_commits() { git log --grep="$1"; }

# Bluetooth connect by nickname (was blueutil; now bluetoothctl).
# NOTE: re-pair your devices on Linux and update these MACs (colon-separated).
function connect() {
  local device_address
  if [[ -z "$1" ]]; then
    echo "Usage: connect <device_name>"
    return 1
  fi
  case "$1" in
    logi) device_address="10:94:97:39:12:F3" ;;
    jbl)  device_address="D8:37:3B:15:08:E3" ;;
    *)    echo "Device '$1' not recognized."; return 1 ;;
  esac
  bluetoothctl disconnect "$device_address"
  bluetoothctl connect "$device_address"
}

function weather() { curl "wttr.in/NYC?3&u"; }

# AI chat via mods (Charm's `mods` CLI). Not installed by this repo — if you
# want these helpers, install mods yourself; otherwise they're harmless until called.
chatgpt() { mods -f "$*"; }

# Ask for a shell command in natural language, confirm, then run it.
smart_shell() {
  local query="$*"
  local result command explanation
  result=$(mods --max-tokens 150 -f \
    "You are a shell command expert. Respond ONLY with a JSON object that has two fields: 'explanation' (a brief one-line explanation) and 'command' (the exact command to run). Example response: {\"explanation\": \"Shows disk usage in human readable format\", \"command\": \"df -h\"}

What is the shell command to $query")
  command=$(echo "$result" | grep -o '{.*}' | jq -r '.command')
  explanation=$(echo "$result" | grep -o '{.*}' | jq -r '.explanation')
  echo "Explanation: $explanation"
  echo "Command to execute: $command"
  echo -e "\nExecute this command? (y/n)"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    echo "Running command..."
    echo "-------------------"
    eval "$command"
  else
    echo "Command cancelled"
  fi
}

# Search file contents/names with options (-e everywhere, -n names only, -c case-sensitive)
search() {
  local phrase="" everywhere=false filenames_only=false case_sensitive=false
  local OPTIND opt
  while getopts ":henc" opt; do
    case ${opt} in
      h) echo "Usage: search [-h] [-e] [-n] [-c] <phrase>"; return 0 ;;
      e) everywhere=true ;;
      n) filenames_only=true ;;
      c) case_sensitive=true ;;
      \?) echo "Invalid option: $OPTARG" 1>&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))
  [[ $# -eq 0 ]] && { echo "Error: Search phrase required. Use -h." 1>&2; return 1; }
  phrase="$1"
  local root="."; $everywhere && root="/"
  if $filenames_only; then
    if $case_sensitive; then find "$root" -type f -name "*$phrase*"
    else find "$root" -type f -iname "*$phrase*"; fi
  else
    if $case_sensitive; then grep -rln "$phrase" "$root"
    else grep -riln "$phrase" "$root"; fi
  fi
}
