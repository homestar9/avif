# AGENTS.md — orientation for AI/coding agents working on the `avif` module

This file is the fast on-ramp for any agent (or human) picking up this repo. It
is intentionally self-contained: the sibling `webp` project it mirrors lives in a
**separate** repository, so the parts you need to know about `webp` are captured
here rather than assumed to be open in your editor.

## What this project is

A **ColdBox / ForgeBox module** (`slug: avif`) that encodes, decodes, and
inspects **AVIF** images from CFML. It is a thin, hardened wrapper around the
**libavif** command-line tools:

- `avifenc.exe` — encode JPEG/PNG/Y4M → AVIF
- `avifdec.exe` — decode AVIF → PNG/JPEG/Y4M, and `--info` for metadata

The binaries are **bundled** (committed) under `bin/win-x64-1.4.2/` and invoked
**directly via Java `ProcessBuilder`** — never through a shell.

**v1 is Windows x64 only** (matches the reality of the `webp` module). OS gating
is isolated in `ModuleConfig.cfc::getBinPath()`, so macOS/Linux can be added later
by extending the binary resolver + bundled artifacts — without touching the public
API.

## The prime directive: hot-swap parity with `webp`

This module is the **hot-swap sister** of the `webp` module. A consuming app (a
CMS, image pipeline, etc.) must be able to change one line —

```cfml
property name="img" inject="webp@webp";   // becomes:
property name="img" inject="avif@avif";
```

— and keep calling `img.encode()`, `img.decode()`, `img.info()` unchanged (only the
output file extension changes, `.webp` → `.avif`).

**When you change a public method signature, protect this invariant.** The shared
argument NAMES must keep matching `webp` for the options both formats truly share.
See the mapping table below.

## Architecture (only two real files)

We deliberately did **not** build a 6-service layered architecture (an earlier
design proposed one — see `plans/AVIF_MODULE_HANDOFF.md`). It is over-engineered
for "shell out to two exes and parse one block of text," and would make this feel
unlike its `webp` sibling. Keep it lean:

- **`models/avif.cfc`** — the WireBox-facing service (`avif@avif`). Public:
  `encode()`, `decode()`, `info()`, `version()`, `capabilities()`. Also holds the
  private validation, `cfimage` transform, atomic-move, info-parse, and version-parse
  helpers.
- **`models/ProcessRunner.cfc`** — the single choke point that runs a binary via
  Java `ProcessBuilder`. Merges stdout+stderr, redirects to a temp file (no
  pipe-buffer deadlock, no reader thread), enforces the timeout, returns
  `{ command, exitCode, output, timedOut, durationMs }`.
- **`ModuleConfig.cfc`** — module metadata + `settings` (`binPath`, `avifencPath`,
  `avifdecPath`, `timeout`, `maxDimension`) + Windows-x64 `getBinPath()` gate.

If you need a new capability, prefer adding a private method to `avif.cfc` over a
new CFC, unless it genuinely earns its own file.

## Gotchas (the stuff that will bite you)

1. **`avifenc`/`avifdec` cannot crop, resize, or flip raster pixels.** `avifenc
   --crop` only writes a "clean aperture" *metadata* property, not a real crop. So
   crop/resize (encode) and crop/resize/flip (decode) are done with ColdFusion's
   native `cfimage` (`imageCrop`/`imageResize`/`imageFlip`) in
   `applyImageTransforms()` — a temp PNG before encode, in-place after decode. This
   is what keeps hot-swap real for a CMS while staying honest about the CLI.
2. **No shell.** Everything goes through `ProcessRunner` (ProcessBuilder). Never
   reintroduce `cmd.exe /c` / `<cfexecute>`. Every argument is its own list element;
   untrusted paths are placed after a `--` end-of-options marker. This is the main
   hardening win over the `webp` module and makes paths with spaces/`&`/`()` safe.
3. **AV1 encoding is slow.** Default `timeout` is 60s (vs webp's 10s) and `speed`
   defaults to 6 (avifenc's default). Big images at low speed can exceed short
   timeouts.
4. **Quality scale.** `avifenc -q` is 0..100 where **100 ≈ lossless** (same
   direction as `cwebp -q`). `quality=80` hot-swaps meaningfully, but the visual
   result differs between formats — that's inherent, not a bug.
5. **WebP-only options are intentionally NOT declared** (`nearLossless`, `preset`,
   `compressionMethod`, `filterStrength/Sharpness/Strong/Weak`, `jpegLike`,
   `sourceHint`, `psnr`, `autoFilter`, `losslessCompressionMode`). CFML silently
   drops undeclared named arguments, so a hot-swapped call passing them still works
   — they're just ignored, honestly. Do not add fake no-op params for them.
6. **Version pin coupling.** The libavif version appears in TWO places that must
   stay in sync: the folder name `bin/win-x64-<version>/` and the string returned by
   `ModuleConfig.cfc::getBinPath()`. Update both together, and re-confirm CLI flags
   against the new binaries.
7. **`info()` parsing.** `avifdec --info` prints ` * Key : Value` lines (e.g.
   `Resolution : 640x480`). The parser normalizes `Resolution` into guaranteed
   numeric `width`/`height` keys (the hot-swap contract). If you bump libavif,
   re-capture `--info` output and confirm the parser still finds them.
8. **`ProcessRunner` output is line/stream text**, merged stderr+stdout. Don't
   assert on English fragments in tests — assert on files + `info()` numbers.

## Public API + argument mapping (webp → avif)

| webp arg (shared) | avif handling | avifenc/avifdec flag |
|---|---|---|
| `source`, `destination` | same | positional after `--` |
| `quality` (0-100) | same, higher=better | `-q` (encode) / `-q` jpeg (decode) |
| `lossless` | same | `-l` |
| `alphaQuality` | same | `--qalpha` |
| `cropX/Y/Width/Height` | **cfimage** crop | (none — raster) |
| `resizeWidth/Height` (0=keep aspect) | **cfimage** resize | (none — raster) |
| `flipImage` (decode) | **cfimage** flip | (none — raster) |
| `multiThreaded` | same | `-j all` / `-j 1` |
| `verbose` | accepted; output always captured | (none) |
| `timeout` (0=use setting) | same | ProcessRunner timeout |
| `metadata="none"` | strip | `--ignore-exif/xmp/icc` |

**AVIF-native additions:** `speed` (`-s`), `depth` (`-d`), `chroma` (`-y`),
`upsampling` (decode `-u`). **Additive methods:** `version()`, `capabilities()`.

`encode()`/`decode()` return the raw tool output **string** (webp parity).
`info()` returns a struct guaranteed to contain numeric `width` + `height`.

## Errors

Typed via `throw(type="...")`: `avif.unsupportedPlatform`, `avif.binaryNotFound`,
`avif.binaryExecutionFailed`, `avif.timeout`, `avif.invalidSource`,
`avif.invalidDestination`, `avif.unsupportedFormat`. Output is written atomically
(temp file in the destination dir, moved on success; temp files cleaned in a
`finally`), so a failed conversion never leaves a partial destination file.

## Dev loop

CommandBox is required. From the repo root:

```
box install                                   # module deps (none) 
cd test-harness && box install && cd ..       # installs coldbox + testbox
box server start serverConfigFile=server-lucee@5.json   # Lucee on :60300
box testbox run                               # runs the integration specs
box server stop serverConfigFile=server-lucee@5.json
```

Tests live in `test-harness/tests/specs/integration/avifTests.cfc` and exercise the
REAL binaries (Windows x64 only). Fixtures: `golden.jpg` (640×480), `dog.png`
(239×320, alpha), `golden.avif` (640×480, regenerate with
`avifenc golden.jpg golden.avif` if needed).

Note: the port is **60300** (webp's harness uses 60299) so both can run at once.

## Reference: the `webp` module we mirror (separate repo)

Location (dev machine): `d:\Dropbox\Repositories\webp` — public repo
`https://github.com/homestar9/webp`.

- **Shape:** one real file, `models/webp.cfc` (singleton, `webp@webp`), plus
  `ModuleConfig.cfc`. Public: `encode()`, `decode()`, `info()`.
- **Backend:** shells out to Google's precompiled WebP binaries
  (`cwebp.exe`/`dwebp.exe`/`webpinfo.exe`) via `<cfexecute>` running
  `cmd.exe /c <bin> <args> 2>&1`. **We replaced this shell model with
  ProcessBuilder.**
- **Settings shape:** `webp = { cmdPath, binPath }`. We kept `binPath` (+ added
  explicit `avifencPath`/`avifdecPath` overrides) and dropped `cmdPath` (no shell).
- **`webp.encode()` args** (the parity target): `source, destination, lossless,
  nearLossless, quality(=80), losslessCompressionMode, alphaQuality, preset,
  compressionMethod, cropX/Y/Width/Height, resizeWidth/Height(=0),
  multiThreaded(=true), lowMemory, size, psnr, pass, autoFilter, jpegLike,
  filterStrength/Sharpness/Strong/Weak, exact, metadata, noAlpha, sourceHint,
  verbose, timeout(=10)`. Returns the raw `cwebp` stdout string.
- **`webp.decode()` args:** `source, destination, cropX/Y/Width/Height,
  resizeWidth/Height, flipImage, multiThreaded, verbose, timeout`. Infers output
  format from the destination extension; dwebp supports png/pam/ppm/pgm/tiff/yuv but
  **not JPG** (a webp limitation we improve on — avifdec writes JPEG directly).
- **`webp.info()`** runs `webpinfo.exe` and returns a struct keyed by (spaces
  stripped) `Width`, `Height`, `Format`, `Alpha`, etc. CFML struct keys are
  case-insensitive, so `result.width` works — which is why our `info()` guarantees
  `width`/`height`.
- **`webp` is Windows-x64-only** and throws on any other OS (same as us). Its
  `box.json` referenced `helpers/` and `build/*` scripts that don't exist; we
  dropped those broken references.

## Verified facts about the bundled binaries (libavif 1.4.2)

- Encoder **aom 3.14.1**, decoder **dav1d 1.5.3**, **libyuv** available.
- The Windows release exes are **statically linked — no adjacent DLLs** and no
  VC++ redist needed.
- Download source (pinned): `windows-artifacts.zip` from
  `https://github.com/AOMediaCodec/libavif/releases/tag/v1.4.2` (also ships
  `linux-artifacts.zip` / `macOS-artifacts.zip` for future platform work).
- `avifenc` key flags: `-q`/`--qcolor`, `--qalpha`, `-l`, `-s`, `-j`, `-d`, `-y`,
  `--ignore-exif/xmp/icc`. `avifdec`: `-q` (jpeg), `-d` (png 8/16), `-u`, `-j`,
  `--info`, `--dimension-limit`, `--size-limit`.
