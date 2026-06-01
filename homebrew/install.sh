#!/bin/sh
#
# Homebrew
#
# This installs some of the common dependencies needed (or at least desired)
# using Homebrew.

# Check for Homebrew
if test ! "$(which brew)"
then
  echo "  Installing Homebrew for you."

  # Install the correct homebrew for each OS type
  if test "$(uname)" = "Darwin"
  then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  elif test "$(expr substr "$(uname -s)" 1 5)" = "Linux"
  then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  fi

fi

install() {
  app=$1
  cask=${2:-}

cat << EOF

-> Installing ${app}...
EOF

  if [ "x$OS" = "xWindows" ]; then
    scoop install "${app}"
  else
    if [ -z "$cask" ]; then
      brew list "${app}" >/dev/null || brew install "${app}"
    else
      brew list "${app}" --cask >/dev/null || brew install "${app}" --cask
    fi
  fi

cat << EOF

-> ${app} installed
EOF
}

install 1password yes
install alt-tab yes
install atuin
install bat
install bottom
install bruno yes
install oven-sh/bun/bun
install claude-code yes
install cmake
install composer
install cowsay
install defaultbrowser
install direnv
install dotenvx/brew/dotenvx
install dust
install elixir
install eza
install fd
install flox yes
install fortune
install fzf
install gh
install git-delta
install git-extras
install go
install google-chrome yes
install google-drive yes
install gum
install helm
install iterm2 yes
install jq
install k6
install k9s
install karabiner-elements yes
install kubectx
install lazygit
install markdownlint-cli2
install mergiraf
install mise
install mprocs
install neovim
install ngrok yes
install oha
install openssl
install orbstack yes
install procs
install pulumi/tap/pulumi
install raycast yes
install readline
install rectangle yes
install ripgrep
install ruff
install secretive yes
install slack yes
install spotify yes
install sqlite3
install starship
install stats yes
install swiftformat
install swiftlint
install tailscale yes
install uv
install wget
install xz
install ykman
install yq
install zed yes
install zlib
install zoxide
install zsh
install zsh-autosuggestions
install zsh-syntax-highlighting
gh extension install seachicken/gh-poi

# Runtime versions (Python, Node, Ruby, Go, Rust, etc.) are managed by mise.
# Configure per-project with `mise use python@3.13` etc., or globally with
# `mise use -g python@3.13`. No bootstrap-time installs needed.

brew cleanup
rm -f -r /Library/Caches/Homebrew/*

exit 0
