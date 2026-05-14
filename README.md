# htop

Standalone build of [htop](https://htop.dev/).

[![CI](https://github.com/unpins/htop/actions/workflows/htop.yml/badge.svg)](https://github.com/unpins/htop/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin htop
```

Or run without installing:

```bash
unpin run htop
```

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

The [Releases](https://github.com/unpins/htop/releases) page has standalone binaries and a `.tar.zst` data archive (man pages and completions) for manual download.
