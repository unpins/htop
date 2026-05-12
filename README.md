# htop

Standalone build of [htop](https://htop.dev/). Runs on any Linux or macOS without external dependencies.

## Installation

You can install this package instantly using the [unpin](https://github.com/unpins/unpin) package manager:

```bash
unpin htop
```

Or run it without installing:

```bash
unpin run htop
```

## Build locally

```bash
nix build github:unpins/htop
./result/bin/htop
```

Or, in one shot:

```bash
nix run github:unpins/htop
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual Download

Standalone binaries and data packages are available on the [Releases](https://github.com/unpins/htop/releases) page.
