# Lazydocker Host Picker

A small Omarchy/Quickshell plugin for choosing a Docker host and opening Lazydocker against it.

## Goal

Make it easy to open Lazydocker on this machine or one of the user's Docker VMs from a single picker, without manually changing the default Docker context.

## User Flow

1. User invokes the picker from the existing Lazydocker shortcut (when integration is enabled), an Omarchy menu entry, or an optional bar control.
2. A Quickshell picker lists Local and configured remote hosts with clear names and connection status where practical.
3. User selects a host.
4. Lazydocker opens in a terminal connected only to that host.
5. User can cancel without changing Docker settings or opening a terminal.

## Functional Requirements

- Use a Quickshell UI consistent with Omarchy; keep the feature self-contained as a user-owned plugin/project rather than modifying packaged Omarchy files.
- Support the local Docker daemon and named remote hosts.
- Use SSH-based Docker connections for remote hosts where supported; do not require an unauthenticated TCP Docker API.
- Do not change the user's active/default Docker context as a side effect.
- Launch Lazydocker in the user's configured terminal and show actionable feedback if Lazydocker, Docker, or SSH is unavailable.
- Handle unreachable hosts gracefully; selecting one must not make the picker hang indefinitely.
- Make host definitions easy to add, remove, and rename without editing the UI logic; store them in a documented user config file.
- Provide a keyboard-friendly picker and a cancel/escape path.
- Provide an enable/disable mechanism for shortcut integration. Enabling redirects the existing Lazydocker shortcut to the picker; disabling restores the exact previous shortcut behavior.
- Do not silently overwrite unrelated keybindings. Preserve the prior binding and make enable/disable idempotent and reversible.
- Keep enable/disable separate from plugin installation/removal so the picker can remain available through its other launch route.

## Launch and Integration

- **Primary launch path:** repurpose the existing Lazydocker shortcut while integration is enabled.
- **Shortcut toggle:** an explicit enable/disable action. Disable restores the prior shortcut, rather than removing it or guessing its original command.
- **Secondary launch path:** expose the picker through an Omarchy menu entry so it remains discoverable without the shortcut.
- **Bar:** optional, not required for the first version. Prefer keeping the bar uncluttered; revisit a bar launcher only if the menu and shortcut are not convenient enough.

## Configuration

- Keep the remote host list in a dedicated user-owned config file, separate from UI code and Omarchy's packaged files.
- Each host entry should support at least a display name and Docker connection target (prefer an SSH Docker endpoint or SSH alias).
- Include Local as a built-in choice; remote host entries are user-editable.
- Document the config format and validate malformed entries with a useful error instead of failing silently.

## Non-Goals for First Version

- Showing containers from multiple Docker hosts in one Lazydocker view.
- Managing or installing Docker on remote VMs.
- Exposing or configuring Docker's TCP API.

## Acceptance Criteria

- The picker opens from an agreed shortcut/menu entry.
- Local and confirmed remote hosts appear with useful labels.
- Choosing Local opens Lazydocker against the local daemon.
- Choosing a remote host opens Lazydocker against that host over SSH.
- The active Docker context remains unchanged before and after either launch.
- Missing or unreachable-host errors are understandable and do not freeze the desktop.
- The plugin can be disabled/removed without disturbing Omarchy's packaged files or unrelated user configuration.

## MVP Implementation

The first implementation is a user-owned Omarchy `panel` plugin in `plugin/`. It can be summoned with:

```sh
omarchy-shell shell summon rafamedeiros.lazydocker-host-picker '{}'
```

The remote-host example is in `config.example.json`; install/copy it to `~/.config/omarchy/lazydocker-host-picker.json` and edit the `hosts` list. The plugin always includes the local Unix socket and reads configured remote Docker endpoints from that file. For SSH hosts, it uses `plugin/docker-ssh-proxy.py` to bridge a local Unix socket to `ssh host docker system dial-stdio`.

The SSH proxy bridges Docker's `system dial-stdio` transport through a local Unix socket for Lazydocker. This supports SSH environments where forwarding a remote Unix socket directly is unavailable, without changing the active Docker context.

`Super+Shift+D` is now overridden in the user-owned `~/.config/hypr/bindings.lua` to run `~/.local/bin/lazydocker-picker-shortcut`; the Omarchy packaged binding files are untouched. The dispatcher defaults to opening the picker. Run `lazydocker-picker-shortcut disable` to make the same key run Omarchy's original `omarchy-launch-docker-tui` command again, or `lazydocker-picker-shortcut enable` to restore the picker. `lazydocker-picker-shortcut status` reports the mode. Local selection uses Omarchy's original launcher, preserving its Docker privilege handling; remote SSH selection uses the stdio proxy.

No bar widget is added. The picker can also be summoned directly through shell IPC.

## Follow-up Requirements

- Identify the existing Lazydocker key combination and command before implementing reversible shortcut integration.
- Decide whether to add a menu route or bar button; current recommendation is menu first, no permanent bar widget.
- Confirm the third VM's SSH alias; `other-docker-host` currently has no Docker CLI.
- Consider preflight/connection status checks and bounded timeouts after the basic picker launches reliably.
