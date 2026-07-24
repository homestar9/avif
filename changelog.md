# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-07-24

- Added Boxlang compatibility when calculating image resizing.

## [1.0.0] - 2026-07-08

Official release. Windows x64 only.

## [0.1.0] - 2026-07-07

### Added

- Initial beta release. Windows x64 only.
- `encode()` — JPEG/PNG/Y4M → AVIF via bundled `avifenc` (libavif 1.4.2).
- `decode()` — AVIF → PNG/JPEG/Y4M via bundled `avifdec` (JPEG output supported
  directly, an improvement over the `webp` sister module).
- `info()` — normalized metadata struct guaranteeing `width`/`height`.
- `version()` and `capabilities()` helper methods.
- Hot-swap compatible interface with the `webp` module: shared argument names for
  the options both formats support.
- Crop/resize (encode) and crop/resize/flip (decode) implemented with native
  `cfimage`, since libavif tools do not perform raster transforms.
- AVIF-native options: `speed`, `depth`, `chroma`, `alphaQuality`, `upsampling`.
- Binaries executed via Java `ProcessBuilder` (no shell) for safe handling of
  paths with spaces/special characters.
- Typed errors, atomic temp-file output with cleanup, configurable timeout, and a
  decode dimension guard.
- TestBox integration suite exercising the real binaries.

[Unreleased]: https://github.com/homestar9/avif/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/homestar9/avif/releases/tag/v0.1.0
