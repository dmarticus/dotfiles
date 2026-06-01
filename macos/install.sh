#!/usr/bin/env bash

if test ! "$(uname)" = "Darwin"
  then
  exit 0
fi

# The Brewfile handles Homebrew-based app and library installs.
# OS updates are intentionally left to System Settings → Software Update
# rather than `softwareupdate -i -a`, which can kick off multi-GB downloads
# in the background mid-bootstrap.