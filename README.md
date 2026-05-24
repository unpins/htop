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

## Build notes

- **Windows is not supported.** htop has per-OS process backends (Linux `/proc`, macOS Mach, several BSDs) but no Windows backend upstream. Cosmopolitan would only paper over that, not provide one — so we ship Linux + macOS only. See [Future: Windows port](#future-windows-port) below.
- **Embedded terminfo fallback.** A curated set of terminfo entries (`xterm-256color`, `screen-256color`, `tmux-256color`, `linux`, `vt100`, …) is baked into the linked `libtinfo.a`, so htop renders correctly on hosts with no `/usr/share/terminfo` (scratch containers, minimal Alpine, busybox-init systems). When the host has terminfo, the system entry still wins.
- **libcap Go bindings disabled** via `GOLANG=no`. They build `goapps/web`, `goapps/setid`, `goapps/gowns` — separate helper binaries that htop doesn't use. Skipping them keeps the build closure smaller; the C side of libcap (`libcap.a`, `libpsx.a`) is unaffected.
- **lm_sensors `sensors-detect` script removed.** It's a Perl script that pulls perl + bash into the closure. htop only consumes `libsensors.a`, never the script, so we drop both the propagated deps and the script itself.
- No upstream features are disabled beyond the items above.

## Future: Windows port

Not on the v1 roadmap, but tractable for someone with NT API experience.

**Scope.** htop's process backend is platform-pluggable — `linux/`, `darwin/`, `freebsd/`, `openbsd/`, `dragonflybsd/`, `solaris/`, `pcp/` each sit under `htop/<os>/` and the `configure` script selects one at build time. A Windows backend would slot in as `htop/windows/`, mirroring the Solaris port in scope (the leanest existing one).

**Estimated effort.** ~2500–3500 lines of new C inside `htop/windows/` plus ~200–400 lines of patches to portable code, broken down roughly:

- `WindowsProcessList.c` (~600–800) — `NtQuerySystemInformation(SystemProcessInformation)` loop, parse the chained `SYSTEM_PROCESS_INFORMATION` buffer, populate Process structs in one snapshot per refresh.
- `WindowsProcess.c` (~400–500) — `Process` subclass with Windows-specific fields (handle count, session ID, integrity level, signing status).
- `WindowsMachine.c` (~300–400) — system-wide stats: `SystemProcessorPerformanceInformation` per core, `GlobalMemoryStatusEx`, `GetTickCount64`. Load average doesn't exist on Windows — either omit or fake from CPU run-queue depth.
- `Platform.c` (~400–500) — signal table maps to `TerminateProcess` (Windows has no real signals), nice maps to `SetPriorityClass`, battery via `GetSystemPowerStatus`.
- `UsersTable.c` (~80–150) — SID → username cache via `LookupAccountSidW` (uncached: one RPC per process per refresh; cache is mandatory).
- Headers, meter overrides, build glue (~700–1000) — struct defs the MinGW SDK doesn't expose, `configure.ac` host detection branch, `Platform.h` dispatch, `Makefile.am` `windows_*_la_SOURCES`.

**Cost drivers beyond LOC.**

- **NT vs Win32 API tradeoff.** `NtQuerySystemInformation` is the only sensible way to get all processes + threads + counters per refresh; calling Win32 (`EnumProcesses` + `OpenProcess` × N + `GetProcessTimes` × N + …) multiplies syscalls and won't sustain 1 Hz with 500+ processes. NT API is undocumented but stable since NT 4.0 — Process Explorer relies on it.
- **PEB walking** to read each process's command line: `NtQueryInformationProcess(ProcessBasicInformation)` → PEB pointer → `ReadProcessMemory` on the `UNICODE_STRING.Buffer`. Races with process exit, fails on elevated targets without `SE_DEBUG_NAME`.
- **UTF-16 boundary.** Every Win32 W-suffix API call needs `wchar_t*` ⇄ `char*` conversion. Roughly 80–100 LOC of conversion plumbing if built under cosmocc (which provides `tprecode16to8`/`tprecode8to16`), or 120–150 LOC under raw mingw (`WideCharToMultiByte` with six parameters and ACP fallback handling). The structural cost — every Win32 surface needs a boundary — is the same with either toolchain.
- **htop core's locale-naive text handling.** Column truncation, incremental search, and width calculation in `htop/Column.c`, `htop/IncSet.c`, etc. truncate by byte count and search via `strstr`. The bugs already exist on Linux for Cyrillic/CJK process names, just less visible. A Windows port surfaces them because the typical Windows process name set has more non-ASCII (`Гостевой пользователь`, Microsoft Windows kanji service names, etc.). Fixing properly is a ~200–400 LOC refactor toward `wcswidth`-aware truncation in portable code.
- **Features that don't translate.** cgroups column, namespace IDs, CAP_* capabilities, per-pid IO bytes (Windows reports operations, not bytes) — each needs `#ifdef` in the UI or a stub.

**Toolchain choice (mingw vs cosmocc).**

- **mingw cross** produces a separate `.exe`, ~120–200 KB stripped, fits the current htop build structure (`configure` selects one backend). Most natural; gives 3 binaries total (Linux + macOS + Windows).
- **cosmocc** would let one APE binary run on Linux + macOS + Windows, but only if the build is also refactored to dispatch backends at runtime via `IsLinux()`/`IsXnu()`/`IsWindows()`. htop's `configure`-time backend selection bakes in `HAVE_LINUX_*` macros throughout — that refactor is the dominant cost, not the Windows backend itself. Worth it only if a single-binary-per-package guarantee is more valuable than ~440 KB extra and a per-syscall dispatch layer.

**Upstream-ability.** htop has accepted platform ports from contributors before (Solaris 2014, FreeBSD 2016, DragonFlyBSD 2018). A clean Windows port has a real chance of merging into `htop-dev/htop` master, especially if it ships as `htop/windows/` with no churn to existing backends. Review will cost an additional 1–2 weeks negotiating portable-code refactors.

**Realistic calendar.** 2–3 weeks full-time for an engineer fluent in both htop internals and the NT API; 6–10 weeks otherwise (most of which goes to `winternl.h` and Process Explorer source). Out of scope for v1; tracked as a v2+ stretch goal. Contributions welcome — open an issue first to align on the toolchain choice above.
