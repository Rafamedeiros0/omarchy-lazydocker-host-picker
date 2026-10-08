# Lazydocker Host Picker

An Omarchy/Quickshell plugin that lets you choose a local or remote Docker host and open Lazydocker for it.

## Features

- Pick the local Docker daemon or a configured remote host over SSH.
- Check host availability without delaying the picker.
- Add, edit, and remove remote hosts in the picker.
- Open from the Omarchy menu or configure a keyboard shortcut.
- Leave the active Docker context unchanged.
- Follow Omarchy's theme colors and styles.

## Requirements

- Omarchy with Quickshell panel plugins and Hyprland.
- Lazydocker; for remote hosts, OpenSSH and Docker access on the remote machine.
- Linux x86_64 for the included helper binaries. Other architectures need Go to run the helpers from source.

Configure SSH access to each remote host before adding it. The picker uses your existing SSH configuration and authentication.

## Install

Clone the repository and run the installer:

```sh
git clone https://github.com/Rafamedeiros0/omarchy-lazydocker-host-picker.git
cd omarchy-lazydocker-host-picker
./plugin/install.sh
```

The installer adds **Trigger → Lazydocker Picker** to the Omarchy menu and offers to set up the `Super+Shift+D` shortcut when it is available. You can configure the shortcut from the picker; resetting it restores Omarchy's Docker action.

To launch the picker directly:

```sh
omarchy-shell shell summon rafamedeiros.lazydocker-host-picker '{}'
```

## Add remote hosts

Open host management in the picker and add a display name and Docker SSH endpoint. The picker checks Docker connectivity before saving.

You can also edit `~/.config/omarchy/lazydocker-host-picker.json` directly. Start with [`config.example.json`](config.example.json), replace the example endpoint, and use unique IDs:

```json
{
  "hosts": [
    {
      "id": "nas",
      "name": "NAS",
      "dockerHost": "ssh://your-user@your-host"
    }
  ]
}
```

The `id` must start with a letter or number and contain only letters, numbers, `.`, `_`, or `-`. The ID `local` is reserved. Local is always included automatically and should not be added to this file.

## Uninstall

From the cloned repository, run:

```sh
./plugin/uninstall.sh
```

The uninstall script removes the plugin and its menu/shortcut integration while preserving your host configuration.

## Troubleshooting

- If the plugin does not appear after installation, restart the Omarchy shell with `omarchy-restart-shell`, then open it from the menu or run the summon command above.
- If a remote host is unreachable, verify that SSH works from a terminal and that the remote account can access Docker.
- On architectures without the included helper binaries, install Go so the helper programs can run from source.

## Contributing

Run both quality checks before submitting changes:

```sh
./scripts/check-plugin-quality.sh
./scripts/check-qml-quality.sh
```

GitHub Actions runs the same checks. Lefthook can run them automatically before each commit; install Lefthook and run `lefthook install` to enable the repository hook.
