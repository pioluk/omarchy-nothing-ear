# Nothing Ear for Omarchy

The Omarchy bar shows battery levels for the left bud, the right bud, and the case. It also shows active noise cancellation (ANC), equalizer presets, in-ear detection, and low latency mode. A Python daemon talks to the earbuds over Bluetooth RFCOMM and publishes their state to a JSON file the panel reads.

## What it shows

- **Battery** for the left bud, the right bud, and the case, each with a charging and in-ear hint.
- **Noise cancellation**: Off, ANC Low, ANC Mid, ANC High, Adaptive, and Transparency.
- **Equalizer**: Balanced, More Bass, More Treble, and Voice.
- **In-ear detection**: pause playback when you remove a bud.
- **Low latency mode**: reduce audio delay while gaming.

The bar icon stays hidden until earbuds connect. Right-click cycles the noise cancellation mode without opening the panel.

## Requirements

- Omarchy with the Quickshell bar and its plugin system.
- BlueZ for `bluetoothctl`. On Omarchy and Arch, this comes from `bluez-utils`.
- Optional `sdptool` from `bluez-deprecated-tools`. Channel probing still runs without it, but discovery is slower.
- Python 3. The daemon imports nothing outside the standard library.
- Node.js to run the test suite.

The plugin targets the Nothing Ear (a). It matches Bluetooth devices named `Nothing Ear` or `CMF Buds`.

## Install

`omarchy plugin add` only clones plugin files, so run `setup` afterward to install the daemon.

```bash
omarchy plugin add https://github.com/pioluk/omarchy-nothing-ear --enable
~/.config/omarchy/plugins/io.github.pioluk.omnothingear/setup
```

`setup` checks for `bluetoothctl`, copies the daemon to `~/.local/bin/nothingear`, and writes the systemd user unit `~/.config/systemd/user/nothingear.service`. It then starts the unit. Because the unit targets `graphical-session.target`, the daemon starts with your session.

The icon stays hidden until earbuds connect. To keep it visible:

```bash
omarchy bar set io.github.pioluk.omnothingear hideWhenDisconnected false --json
```

## Remove

```bash
systemctl --user disable --now nothingear.service
rm -f ~/.config/systemd/user/nothingear.service ~/.local/bin/nothingear
rm -rf ~/.local/state/nothingear
omarchy plugin remove io.github.pioluk.omnothingear
```

The daemon installs into `~/.local`, outside the plugin directory, so remove it manually before or after the plugin.

## Keyboard

| Key | Action |
|-----|--------|
| `j` / `k`, `↓` / `↑` | Move between rows |
| `enter` / `space` | Activate the current row |
| `o` | Off |
| `l` | ANC Low |
| `m` | ANC Mid |
| `h` | ANC High |
| `a` | Adaptive |
| `t` | Transparency |
| `e` | Cycle the equalizer preset |
| `d` | Toggle in-ear detection |
| `g` | Toggle low latency mode |
| `r` | Refresh |
| `tab` | Move to the next panel |
| `esc` | Close |

Left-click opens the panel. Right-click cycles the noise cancellation mode.

## Settings

| Setting | Default | Notes |
|---------|---------|-------|
| Hide when disconnected | on | Hide the bar icon when no Nothing Ear devices are connected, instead of leaving it with nothing to show. |
| Path to nothingear | empty | Leave empty to find `nothingear` on `PATH`. |

## The daemon

The daemon owns the Bluetooth connection. It discovers the right RFCOMM channel, polls battery and settings every 5s, and writes `$XDG_STATE_HOME/nothingear/status.json` whenever the state changes. It removes that file when it stops.

The panel never talks to Bluetooth. It watches and reads the status file, so an idle desktop runs no extra processes on its behalf. When you change a setting, the panel writes a small request file. The daemon applies the request, which keeps the panel from competing for the same RFCOMM socket.

You can drive the daemon from a shell without the bar:

```bash
nothingear status
nothingear info
nothingear anc transparency
nothingear eq bass
nothingear ear on
nothingear latency on
```

`status` prints the cached JSON. `info` prints the device name, model, firmware, and serial number. The four control commands fail with a message when no earbuds are connected.

## Tests

`Model.js` holds the parsing and formatting, with no QML imports, so it runs outside the shell. The suite covers failure cases: an empty status file, a line that is not JSON, and a schema version newer than the panel supports.

```bash
./test.sh
```

## Credits

[omarchy-pods](https://github.com/thisisgm/omarchy-pods) by thisisgm inspired the bar widget and showed how to draw earbud battery and controls in the Omarchy panel idiom.

The daemon implements the Nothing Ear protocol. Its constants come from the public reverse-engineering work in Something X and earctl, which documented the RFCOMM framing, battery payloads, and noise cancellation commands.

## Licence

Released under the MIT licence.
