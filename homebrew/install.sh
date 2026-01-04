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
install cmake
install composer
install cowsay
install direnv
install dotenvx/brew/dotenvx
install elixir
install fortune
install fzf
install gh
install git-extras
install go
install google-drive yes
install helm
install hey
install iterm2 yes
install jetbrains-toolbox yes
install jq
install k6
install k9s
install kubectx
install libmaxminddb
install libxmlsec1
install llvm
install markdownlint-cli2
install mergiraf
install mprocs
install ngrok yes
install nvm
install openssl
install pngquant
install postman yes
install postgresql@14
install pulumi/tap/pulumi
install pyenv
install python@3.10
install python@3.11
install python@3.12
install rbenv
install readline
install ripgrep
install ruby
install ruby-install
install ruff
install rustup
install secretive yes
install slack yes
install spotify yes
install sqlite3
install swiftformat
install swiftlint
install tree
install uv
install vips
install visual-studio-code yes
install wezterm yes
install wget
install xz
install ykman
install yq
install zlib
install zsh
install zsh-syntax-highlighting
gh extension install seachicken/gh-poi

# Install Rust
if test ! "$(which rustup)"
then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

# You may need to run these commands for ruby-installer to work.
# export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
# export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@1.1/lib/pkgconfig"
# export LDFLAGS="-L/opt/homebrew/opt/openssl@1.1/lib"
# export CPPFLAGS="-I/opt/homebrew/opt/openssl@1.1/include"
ruby-install ruby 3.1.3
gem install jekyll --user-install

curl https://pyenv.run | bash

brew cleanup
rm -f -r /Library/Caches/Homebrew/*

exit 0
