# Changelog

## [v0.1.0] - 2026-09-08

### Added

- Published under the [GWRG distribution
  spec](https://github.com/slash-proc/gwrg-dist-spec): a `manifest.json`
  describing this core and the system it provides, an offline bundle, and a
  GitHub Pages mirror of `dist/` that a web installer can read without a human
  in the loop.
- `symbols[]` publishes the linked ELF so a crash address from a device can be
  resolved back to a function. It is named by the manifest and mirrored, but is
  not part of the install set and never reaches the card.
- `gwrg.json`, the hand-written half of the manifest: the short console name
  and whether compressed ROMs work. Everything else -- the system, its folder,
  extensions and browse mode, the firmware ABI, sizes and hashes -- is derived
  from the packed binary at release time, so the manifest and the firmware
  cannot disagree about which folder the system reads.
- No BIOS is declared. Caprice32 emulates the CPC firmware itself and reads
  nothing from `/bios/`, and a multi-disk game is a set of siblings the core
  steps through by scanning the folder, not a game whose first file names its
  companions, so its extensions stay ungrouped.

### Changed

- `scripts/make_manifest.py`, `build_dist.py`, `make_bundle.py` and
  `stage_release.py` are now the shared copies, byte-identical across every
  project. A script that has to be edited on the way in is a script that
  drifts.
- The Makefile answers `print-SIDECARS` and `print-RO_BIN`. This core installs
  neither, but the shared release script reads its variables positionally: a
  missing target shifts every later value onto the wrong name.

## [v0.0.1]

Initial release

### Added

- Nothing

### Changed

- Nothing

### Fixed

- Nothing

### Install

**Core**

- Copy `caprice32.bin` to `/cores/` on the SD card.
- Place test ROMs under `/roms/amstrad/`.
- Requires firmware whose ABI matches `SDK_VERSION` in this repository.
