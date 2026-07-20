#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

nvim --headless -n -i NONE -u NONE \
  "+luafile $repo_dir/tests/navigation_spec.lua" \
  "+qa!"

nvim --headless -n -i NONE -u NONE \
  "+luafile $repo_dir/tests/ai_sidebar_spec.lua" \
  "+qa!"
