#!/usr/bin/env bash
set -euo pipefail

plugin_id="rafamedeiros.lazydocker-host-picker"
integration="$HOME/.local/bin/lazydocker-picker-integration"
plugin_target="$HOME/.config/omarchy/plugins/$plugin_id"
manager_lib="$HOME/.local/lib/lazydocker-host-picker"

if [[ -x "$integration" ]]; then
  "$integration" reset
  "$integration" menu-remove
fi

rm -rf -- "$plugin_target"
rm -f -- "$HOME/.local/bin/lazydocker-picker-shortcut" "$integration"
rm -rf -- "$manager_lib"
omarchy-shell shell rescanPlugins
printf 'Uninstalled %s. Host configuration was preserved.\n' "$plugin_id"
