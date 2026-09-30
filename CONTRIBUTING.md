# Working on OmaKraken

## Layout

| Path | What it is |
| --- | --- |
| `manifest.json` | Omarchy plugin manifest (service + bar widget) |
| `qml/Service.qml` | Runs the helper, battery alerts, mic volume through PipeWire |
| `qml/BarWidget.qml` | Bar icon and dropdown |
| `qml/Api.js` | Shared helpers for the QML |
| `helpers/omakrakenctl` | Python helper that talks to the dongle |
| `udev/70-razer-kraken.rules` | The udev rule users install once |
| `scripts/` | Developer install, uninstall and checks |

## Developer install

`scripts/install.sh` copies `manifest.json`, `qml/`, `helpers/` and `udev/`
into `~/.config/omarchy/plugins/io.github.dankestrick.omakraken/`. It only
replaces a folder it created itself and that still holds exactly the files it
installed (a marker lists each file with its SHA-256). A checkout from
`omarchy plugin add`, or a folder with your own files in it, is left alone.

From a checkout of this repository:

```bash
scripts/install.sh
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.dankestrick.omakraken
```

After changing QML or the helper, run `scripts/install.sh` again. If the
service looks stale, `omarchy restart shell`.

## Checks

```bash
scripts/validate.sh
```

It runs `omarchy plugin validate`, `qmllint` on every QML file, checks that
every `Text` sets `textFormat`, compiles the helper, and checks for symlinks.

## The protocol

The dongle's settings channel is the CDC serial port (`/dev/ttyACMn`, USB
interfaces 4 and 5). Open it raw and set DTR and RTS. Each command is a
28-byte Bluetooth HCI vendor packet:

```
01 f3 ff 18 | 02 <21 write / 20 read> <b6> <b7 .. b26> <checksum>
checksum = -(sum of bytes 7..26) & 0xff
```

The headset answers with `04 0e 1c 01 f3 ff <status> <echo...>`.

| Setting | Bytes 6.. |
| --- | --- |
| Sidetone | `25 <on 0/1> <level 0-4>` |
| Power saving | `26 <on 0/1> <seconds, little-endian>` (900-3600) |
| Haptics | `40 8a 00 <on 0/1> <level 1-3>` |
| Brightness | `40 8e 00 00 <0-255>` |
| Color | `40 8c 00 00 08 01 <R> <G> <B>` |

Reads (`20`): `21` serial number (ASCII), `24` `<flags> 0f <link> <battery %>` (flags bit `0x04` = charging),
`25` sidetone, `26` power saving. The `40` group is write-only.

Mic volume is standard USB audio. Plugging or unplugging the charger can stop
the settings channel until the dongle is replugged; audio is not affected.
