#!/bin/sh

export ZSH=$HOME/.dotfiles

mkdir -p ~/.config

src="$ZSH/starship/starship.toml"
dst="$HOME/.config/starship.toml"

if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    exit 0
fi

if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.backup.$(date +%Y%m%d_%H%M%S)"
fi

rm -f "$dst"
ln -s "$src" "$dst"
