#!/bin/sh

export ZSH=$HOME/.dotfiles

mkdir -p ~/.config/zed

for file in settings.json keymap.json; do
    src="$ZSH/zed/$file"
    dst="$HOME/.config/zed/$file"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        continue
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    rm -f "$dst"
    ln -s "$src" "$dst"
done
