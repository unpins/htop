# htop

[htop](https://htop.dev/) as a single self-contained binary, built natively for Linux and macOS.

[![CI](https://github.com/unpins/htop/actions/workflows/htop.yml/badge.svg)](https://github.com/unpins/htop/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install htop`.

## Usage

Run the `htop` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin htop
```

To install it onto your PATH:

```bash
unpin install htop
```

## Man pages

`htop.1` is embedded in the binary — read it with `unpin man htop`.

## Build locally

```bash
nix build github:unpins/htop
./result/bin/htop
```

Or run directly:

```bash
nix run github:unpins/htop
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/htop/releases) page has standalone binaries for manual download.

## Build notes

- **Windows is not supported.** htop has per-OS process backends (Linux `/proc`, macOS Mach, several BSDs) but no Windows backend upstream. Cosmopolitan would only paper over that, not provide one — so we ship Linux + macOS only.
- **Embedded terminfo fallback.** A curated set of terminfo entries (`xterm-256color`, `screen-256color`, `tmux-256color`, `linux`, `vt100`, …) is baked into the linked `libtinfo.a`, so htop renders correctly on hosts with no `/usr/share/terminfo` (scratch containers, minimal Alpine, busybox-init systems). When the host has terminfo, the system entry still wins.
- **libcap Go bindings disabled** via `GOLANG=no`. They build `goapps/web`, `goapps/setid`, `goapps/gowns` — separate helper binaries that htop doesn't use. Skipping them keeps the build closure smaller; the C side of libcap (`libcap.a`, `libpsx.a`) is unaffected.
- **lm_sensors `sensors-detect` script removed.** It's a Perl script that pulls perl + bash into the closure. htop only consumes `libsensors.a`, never the script, so we drop both the propagated deps and the script itself.
- No upstream features are disabled beyond the items above.
