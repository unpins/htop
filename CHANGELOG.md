# Changelog

## [Unreleased]

### Fixed

- The binary no longer carries paths into the machine that built it. The
  v3.5.1-1 release had five of them baked in — the loader path for libnl and
  the terminfo directory — all naming directories that do not exist on your
  computer. htop behaved the same either way (it never loaded the library, and
  the terminfo lookup already fell through to the system database), but nothing
  in the binary points outside itself now.

### Changed

- Built by the same compiler as the rest of the catalog. The binary grew from
  826 KB to 874 KB. Checked on Linux x86_64 and arm64: the interface draws,
  the meters update, and it quits cleanly.
