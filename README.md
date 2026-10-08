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

- Use Omarchy's shared Quickshell `Color` and `Style` tokens for surfaces, text, accents, borders, spacing, and typography. Do not hard-code theme colors; the picker must follow theme changes without edits or restart when the shell exposes live theme updates.
- Support the local Docker daemon and named remote hosts.
- Use SSH-based Docker connections for remote hosts where supported; do not require an unauthenticated TCP Docker API.
- Do not change the user's active/default Docker context as a side effect.
- Launch Lazydocker in the user's configured terminal and show actionable feedback if Lazydocker, Docker, or SSH is unavailable.
- Handle unreachable hosts gracefully; selecting one must not make the picker hang indefinitely.
- Make host definitions easy to add without editing JSON by hand; store them in a documented user config file.
- Include a built-in, non-removable Local choice.
- Provide a keyboard-friendly picker and a cancel/escape path.
- Show a compact status indicator at the trailing/right edge of each host row. Keep the row label unobstructed; show status text in a tooltip on hover and keyboard focus.
- Use theme-aware status colors: `Color.accent` for Online, `Color.urgent` for Unreachable, and `Color.muted` for Checking/Unknown. Do not rely on color alone; tooltips include the state and, when available, the Docker server version.
- Start status checks asynchronously so the picker appears immediately. Bound each probe with a short timeout and keep one slow/offline host from delaying other rows.
- Provide an Add Host flow with a display name and SSH Docker endpoint/alias. Validate the endpoint and verify Docker connectivity before saving; report useful errors and leave the existing config unchanged on failure.
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
- Each remote host entry supports a display name and SSH Docker endpoint/alias.
- Local is built in and is not stored among removable remote hosts.
- The Add Host flow writes valid remote entries to the user config without changing unrelated settings.
- Document the config format and validate malformed entries with a useful error instead of failing silently.
- Require unique remote host IDs that start with a letter or number and use only letters, numbers, `.`, `_`, or `-`; reserve `local` and reject duplicate SSH endpoints so row status and edits cannot collide.

## Non-Goals for First Version

- Showing containers from multiple Docker hosts in one Lazydocker view.
- Managing or installing Docker on remote VMs.
- Exposing or configuring Docker's TCP API.

## Acceptance Criteria

- The picker opens from an agreed shortcut/menu entry.
- Local and configured remote hosts appear with useful labels and right-aligned status dots; hover/focus reveals status text.
- Host checks are asynchronous and time-bounded; a failed remote does not block the picker.
- The picker follows Omarchy theme changes through shared theme tokens rather than fixed colors.
- The Add Host flow validates and tests a remote before saving it.
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

The remote-host example is in `config.example.json`; install/copy it to `~/.config/omarchy/lazydocker-host-picker.json` and edit the `hosts` list. The plugin always includes the local Unix socket and reads configured remote Docker endpoints from that file. For SSH hosts, `plugin/docker-ssh-proxy-launcher` runs the bundled Linux amd64 proxy when available and falls back to `go run` otherwise. Before launching a remote, the picker checks that a proxy route, SSH, and Lazydocker are available; failures appear in the picker and leave it open. The fallback needs Go.

### QML layout

`Panel.qml` coordinates plugin lifecycle, notification state, and the picker window. `PickerWindow.qml` composes the floating window, card, and secondary surfaces. `PickerHeader.qml`, `PickerHostSection.qml`, and `PickerKeyboardHandler.qml` split header controls, the host list and notifications, and keyboard flow into focused parts. `HostManager.qml` owns host status, edit and draft state, Docker connection checks, and host mutations. `DockerLauncher.qml` owns local/SSH launches and proxy readiness checks. `HostConfigStore.qml` owns config parsing, validation, atomic writes, and rollback. `ShortcutController.qml` owns shortcut capture and integration commands. Reusable rows and secondary screens live under `plugin/components/`:

- `HostRow.qml` renders and probes a configured host, including edit and remove actions.
- `HostDraftRow.qml` contains the inline add-host form for one independent draft.
- `HostConfigStore.qml` owns the user config file and validates host IDs and SSH endpoints.
- `HostManager.qml` coordinates host status, edits, add-host drafts, and Docker connection checks.
- `DockerLauncher.qml` starts Lazydocker locally or through the SSH proxy and reports proxy readiness issues.
- `ShortcutController.qml` handles key capture, conflict checks, and shortcut updates.
- `RequirementsView.qml`, `ShortcutSettings.qml`, and `NotificationDetails.qml` own their respective secondary UI states.

The installer copies the entry point, window, its focused subcomponents, and the `components/` directory together so local QML imports work in the installed plugin.

### Plugin development checks

Run `./scripts/check-plugin-quality.sh` and `./scripts/check-qml-quality.sh` before handing off plugin changes. CI and the pre-commit hook use these same entry points. The plugin check runs Go tests and vet, checks Go formatting, and parses the shell scripts. The QML check uses a pinned Arch toolchain and pinned Omarchy type context in CI. Locally, with a working Docker daemon, it builds and reuses that toolchain from `scripts/qml-quality.Dockerfile`; without Docker, it uses installed Qt tools and Omarchy types from `OMARCHY_QML_COMMONS_DIR`, `OMARCHY_PATH`, or `/usr/share/omarchy`, then falls back to the pinned Omarchy checkout. It prefers Qt 6 tools in `/usr/lib/qt6/bin`; set `QT6_QML_TOOLS_DIR` when they are elsewhere. On Arch, format a file with `/usr/lib/qt6/bin/qmlformat -i plugin/PickerWindow.qml`, then rerun the quality script.

To block commits when these checks fail, install Lefthook and its repository hook once:

```sh
go install github.com/evilmartians/lefthook/v2@v2.1.14
lefthook install
```

This requires Go 1.26 or newer. The same check can be run manually with `lefthook run pre-commit` or `./scripts/check-qml-quality.sh`.

After changes to window lifecycle, keyboard behavior, or plugin integration, do a brief smoke check in the Omarchy shell:

1. Rescan or restart the shell if needed, then summon the picker with the command above.
2. Move selection, enter and leave host management, and close with Escape.
3. Exercise the changed flow in the running shell and confirm feedback and window state behave as expected.

Use Qt Creator's QML Profiler when a repeatable interaction shows lag or stutter. Profile that interaction with QML debugging/profiling enabled in the host, then inspect the trace for expensive JavaScript, bindings, or signal handlers. It is a diagnostic tool for observed performance issues, not a required step for every change.

The GitHub Actions workflow runs `scripts/check-qml-quality.sh` on an Ubuntu runner. The script builds the same pinned Arch toolchain used for local checks and installs Qt and Quickshell from the matching Arch package snapshot.

To preview proxy availability messages in the picker, add the `proxyTest` object from `config.proxy-test.example.json` to `~/.config/omarchy/lazydocker-host-picker.json`, alongside `hosts`. Edit its scenario values and set `enabled` to `true`. This uses the same config file the picker already reads for hosts. Test mode does not launch Lazydocker. Set `enabled` to `false` or remove `proxyTest` to restore normal behavior. In normal mode, the picker checks requirements on open. If any are missing, it shows a dedicated issue screen with one bullet per problem; when everything is ready, it opens the host picker without a readiness message.

Example scenarios: `architecture: "x86_64"`, `bundledBinary: true` previews the ready state; `architecture: "arm64"`, `goAvailable: true` previews the ready state; `architecture: "arm64"`, `goAvailable: false` previews the Go requirement. Set `sshAvailable` or `lazydockerAvailable` to `false` to preview those issues. Multiple false values show multiple bullets together.

During local QML development, if the visible picker still shows an older UI after syncing the plugin and rescanning, run `omarchy-restart-shell` before reopening it; the running shell can retain an old panel instance across plugin rescans.

The SSH proxy bridges Docker's `system dial-stdio` transport through a local Unix socket for Lazydocker. This supports SSH environments where forwarding a remote Unix socket directly is unavailable, without changing the active Docker context.

`Super+Shift+D` is now overridden in the user-owned `~/.config/hypr/bindings.lua` to run `~/.local/bin/lazydocker-picker-shortcut`; the Omarchy packaged binding files are untouched. The dispatcher defaults to opening the picker. Run `lazydocker-picker-shortcut disable` to make the same key run Omarchy's original `omarchy-launch-docker-tui` command again, or `lazydocker-picker-shortcut enable` to restore the picker. `lazydocker-picker-shortcut status` reports the mode. Local selection uses Omarchy's original launcher, preserving its Docker privilege handling; remote SSH selection uses the stdio proxy.

No bar widget is added. The picker can also be summoned directly through shell IPC.

## Current UI Improvements

- The picker now uses Omarchy `Color` and `Style` tokens for live theme-aware colors, typography, spacing, and rounding.
- Host rows use theme-token card surfaces in both View and Edit modes. Hover or keyboard selection gets a stronger theme-accent fill/border. A single colored status dot sits before the host name; the connection target is on line two. Docker version and the redundant "Online" label are omitted.
- Docker health checks run asynchronously per host with a six-second timeout. View mode shows Local and online remotes; Edit mode lists every configured host, including offline ones, with an offline-count badge on the Edit icon.
- Press `E` or click the right-aligned pencil icon to enter host-management mode; hover reveals its label. The icon changes to a return arrow while editing. Changes apply immediately.
- Local stays fixed in Edit mode. Each remote row exposes an editable name and SSH endpoint on separate lines, with the status dot beside the name. An icon-only Save control tests Docker access before applying changes; the destructive-color trash control remains separate and confirmed.
- Each **+** click appends an independent inline host draft after the saved hosts. Every draft has its own name, SSH endpoint, Save, and Remove controls; Remove discards only that draft. Save tests Docker connectivity before persisting that host, with checks serialized while other drafts remain editable. Returning to View uses a two-click warning to discard all remaining drafts.
- The picker reserves a stable card height across view/edit modes to minimize layout movement.
- The local row remains selectable to preserve Omarchy's privilege-gated local Docker launcher, even if the unprivileged status probe cannot access the daemon.
- Success, error, and connection-progress feedback appears in a reserved toast slot below the host list (and below the inline new-host row when open). It does not shift the host rows. Long notices include **Details** with wrapped, scrollable text; success notices auto-dismiss, while errors remain until dismissed.
- The third VM's SSH alias is still unknown; it can be added later through the host flow.
