#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
plugin_id="rafamedeiros.lazydocker-host-picker"
plugin_target="$HOME/.config/omarchy/plugins/$plugin_id"
local_bin="$HOME/.local/bin"
local_lib="$HOME/.local/lib/lazydocker-host-picker"
manager_target="$local_bin/lazydocker-picker-integration"

required_files=(
  manifest.json
  Panel.qml
  PickerWindow.qml
  PickerHeader.qml
  PickerHostSection.qml
  PickerKeyboardHandler.qml
  components/HostConfigModel.js
  docker-ssh-proxy.go
  docker-ssh-proxy-launcher
  docker-ssh-proxy-linux-amd64
)
for file in "${required_files[@]}"; do
  [[ -f "$plugin_dir/$file" ]] || { printf 'Missing plugin file: %s\n' "$plugin_dir/$file" >&2; exit 1; }
done
component_files=("$plugin_dir"/components/*.qml "$plugin_dir"/components/*.js)
[[ -f "${component_files[0]}" ]] || { printf 'Missing QML components in %s/components.\n' "$plugin_dir" >&2; exit 1; }
[[ -f "$plugin_dir/lazydocker-picker-integration-linux-amd64" ]] || { printf 'Build the integration manager binary first.\n' >&2; exit 1; }
[[ -f "$plugin_dir/integration/main.go" ]] || { printf 'Missing Go integration manager source.\n' >&2; exit 1; }

install -d "$plugin_target/components" "$local_bin" "$local_lib/integration"
install -m 0644 "$plugin_dir/manifest.json" "$plugin_target/manifest.json"
install -m 0644 "$plugin_dir/Panel.qml" "$plugin_target/Panel.qml"
install -m 0644 "$plugin_dir/PickerWindow.qml" "$plugin_target/PickerWindow.qml"
install -m 0644 "$plugin_dir/PickerHeader.qml" "$plugin_target/PickerHeader.qml"
install -m 0644 "$plugin_dir/PickerHostSection.qml" "$plugin_target/PickerHostSection.qml"
install -m 0644 "$plugin_dir/PickerKeyboardHandler.qml" "$plugin_target/PickerKeyboardHandler.qml"
for component in "${component_files[@]}"; do
  install -m 0644 "$component" "$plugin_target/components/$(basename -- "$component")"
done
install -m 0644 "$plugin_dir/docker-ssh-proxy.go" "$plugin_target/docker-ssh-proxy.go"
install -m 0755 "$plugin_dir/docker-ssh-proxy-launcher" "$plugin_target/docker-ssh-proxy-launcher"
install -m 0755 "$plugin_dir/docker-ssh-proxy-linux-amd64" "$plugin_target/docker-ssh-proxy-linux-amd64"
install -m 0755 "$plugin_dir/lazydocker-picker-shortcut" "$local_bin/lazydocker-picker-shortcut"
install -m 0755 "$plugin_dir/lazydocker-picker-integration" "$manager_target"
install -m 0755 "$plugin_dir/lazydocker-picker-integration-linux-amd64" "$local_lib/lazydocker-picker-integration-linux-amd64"
install -m 0644 "$plugin_dir/integration/main.go" "$local_lib/integration/main.go"

if "$manager_target" menu-add; then
  printf 'Menu entry ready: Trigger > Lazydocker Picker.\n'
else
  printf 'Menu integration was not changed; resolve the reported conflict manually.\n' >&2
fi

state_file="$HOME/.config/omarchy/lazydocker-host-picker-shortcut.json"
if [[ -f "$state_file" ]]; then
  printf 'Kept existing picker shortcut setting.\n'
else
  conflicts="$("$manager_target" check 'SUPER + SHIFT + D')"
  if [[ "$conflicts" != *'"ok":true'* ]]; then
    printf 'Could not inspect shortcut conflicts: %s\n' "$conflicts" >&2
    exit 1
  elif [[ "$conflicts" == *'"conflicts":[]'* ]]; then
    answer="y"
  else
    printf 'Super+Shift+D is already assigned. Conflict details: %s\n' "$conflicts"
    if [[ -t 0 ]]; then
      read -r -p 'Replace it with Lazydocker Picker? [y/N] ' answer
    else
      answer="n"
    fi
  fi
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if [[ "$conflicts" == *'"conflicts":[]'* ]]; then
      "$manager_target" set 'SUPER + SHIFT + D'
    else
      "$manager_target" set 'SUPER + SHIFT + D' --replace
    fi
    printf 'Enabled picker shortcut: Super+Shift+D. Reset from picker settings to restore Omarchy\x27s Docker launcher.\n'
  else
    printf 'Kept the existing Super+Shift+D binding. Configure another shortcut in picker settings later.\n'
  fi
fi

omarchy-shell shell rescanPlugins
printf 'Installed %s. Host config was left untouched.\n' "$plugin_id"
