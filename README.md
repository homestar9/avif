# avif

![AVIF Logo](https://github.com/homestar9/avif/blob/main/avif-logo.avif?raw=true)

AVIF is a ColdBox module that provides a simple API for converting images into
[AVIF](https://en.wikipedia.org/wiki/AVIF) format, decoding AVIF images back into
PNG/JPEG, and inspecting AVIF files. It uses the precompiled
[libavif](https://github.com/AOMediaCodec/libavif) command-line binaries
(`avifenc` / `avifdec`).

It is a **hot-swap sister module** to [`webp`](https://github.com/homestar9/webp):
the API mirrors the `webp` module's methods and shared argument names, so a
consuming app (like a CMS) can switch `webp@webp` for `avif@avif` with no
call-site changes — only the output file extension changes.

## Why AVIF?

AVIF is a modern, royalty-free image format based on the AV1 video codec. It
typically achieves **smaller files than both JPEG and WebP** at comparable quality,
supports alpha transparency, wide color gamut, and high bit depth. It is
[supported by all major modern browsers](https://caniuse.com/avif).

## AVIF support in ColdFusion

Neither Adobe ColdFusion nor Lucee ship native AVIF encoding. This module fills that gap by driving the official libavif binaries, so both engines can produce and consume AVIF without built-in image support.

## Requirements

- Lucee 5+, Adobe ColdFusion 2023+, Boxlang 1.0+
- ColdBox 8+
- Windows x64 (for now — see Known Limitations)
- Permission for the CFML runtime to launch child processes

## Installation

```
box install avif
```

The module detects your platform and points at the bundled binaries. To override
(e.g. to use your own libavif build), set module settings in your `Coldbox.cfc`:

```cfml
moduleSettings = {
    avif = {
        avifencPath  : "C:\tools\libavif\avifenc.exe", // explicit encoder path
        avifdecPath  : "C:\tools\libavif\avifdec.exe", // explicit decoder path
        timeout      : 90,     // default seconds before a conversion is killed
        maxDimension : 16384   // decode guard (avifdec --dimension-limit); 0 = off
    }
};
```

Alternatively, override just the folder that contains the binaries via `binPath`.

## Usage

Inject the model with WireBox:

```cfml
property name="avif" inject="avif@avif";
```

Encode an image into AVIF:

```cfml
avif.encode(
    source      = "path/to/image.jpg",
    destination = "path/to/image.avif"
);
```

Decode an AVIF image into another format (PNG or JPEG — unlike WebP, JPEG is
supported directly):

```cfml
avif.decode(
    source      = "path/to/image.avif",
    destination = "path/to/image.png"
);
```

Get information about an AVIF image:

```cfml
var meta = avif.info( source = "path/to/image.avif" );
// meta.width, meta.height, meta.depth, meta.alpha, meta.chroma, ...
```

Supported decode output formats: **PNG, JPEG, Y4M** (inferred from the destination extension).

### Hot-swapping with the `webp` module

Because the shared argument names match, the same call site works against either
module:

```cfml
// Works identically whether `img` is webp@webp or avif@avif:
img.encode( source = upload, destination = target, quality = 80, resizeWidth = 800 );
```

`avifenc`/`avifdec` cannot crop or resize raster pixels themselves, so this module
performs `cropX/Y/Width/Height` and `resizeWidth/resizeHeight` (and `flipImage` on
decode) using ColdFusion's native `cfimage` functions — giving you the same
behavior a CMS expects from the `webp` module.

### Encode arguments

| Argument | Type | Default | Description |
|---|---|---|---|
| `source` | string | | Full path to the source file (JPEG/PNG/Y4M) |
| `destination` | string | | Full path to the `.avif` output |
| `quality` | int (0-100) | 80 | Color quality; 100 ≈ lossless (`avifenc -q`) |
| `lossless` | boolean | false | Encode losslessly (`avifenc -l`) |
| `alphaQuality` | int (0-100) | | Alpha channel quality (`avifenc --qalpha`) |
| `cropX/Y/Width/Height` | int | | Pixel crop (all four together; via `cfimage`) |
| `resizeWidth` | int | 0 | Resize width; 0 preserves aspect ratio (via `cfimage`) |
| `resizeHeight` | int | 0 | Resize height; 0 preserves aspect ratio (via `cfimage`) |
| `multiThreaded` | boolean | true | Use all worker threads (`avifenc -j all`) |
| `metadata` | string | | `"none"` strips EXIF/XMP/ICC; otherwise preserved |
| `overwrite` | boolean | true | Replace an existing destination |
| `verbose` | boolean | false | Accepted for parity; output is always captured |
| `timeout` | int | 0 | Seconds before the process is killed (0 = module setting) |
| `speed` | int (0-10) | 6 | Encoder speed/effort; 0 slowest/best (`avifenc -s`) |
| `depth` | int (8/10/12) | | Output bit depth (`avifenc -d`) |
| `chroma` | string | | `auto`/`444`/`422`/`420`/`400` (`avifenc -y`) |

> **Hot-swap note:** WebP-specific options (`nearLossless`, `preset`,
> `compressionMethod`, `filterStrength`, `jpegLike`, `sourceHint`, …) have no AVIF
> equivalent. You can leave them in a hot-swapped call — CFML simply ignores
> arguments this module doesn't declare, so nothing breaks; they just have no effect.

### Decode arguments

| Argument | Type | Default | Description |
|---|---|---|---|
| `source` | string | | Full path to the `.avif` source |
| `destination` | string | | Output path (`.png`, `.jpg`, `.jpeg`, `.y4m`) |
| `quality` | int (0-100) | 90 | JPEG output quality (JPEG destinations only, `avifdec -q`) |
| `depth` | int (8/16) | | PNG output depth (PNG destinations only, `avifdec -d`) |
| `upsampling` | string | automatic | Chroma upsampling (`avifdec -u`) |
| `cropX/Y/Width/Height` | int | | Pixel crop (via `cfimage`) |
| `resizeWidth/resizeHeight` | int | 0 | Resize; 0 preserves aspect ratio (via `cfimage`) |
| `flipImage` | boolean | false | Flip vertically (via `cfimage`) |
| `multiThreaded` | boolean | true | Use all worker threads (`avifdec -j all`) |
| `overwrite` | boolean | true | Replace an existing destination |
| `verbose` | boolean | false | Accepted for parity; output is always captured |
| `timeout` | int | 0 | Seconds before the process is killed (0 = module setting) |

### info() / version() / capabilities()

- `info( source )` → struct guaranteed to include numeric `width` and `height`,
  plus `depth`, `alpha`, `chroma`, and the raw parsed keys (`Resolution`,
  `BitDepth`, `Format`, `Range`, …). Pass `verbose=true` to include `rawOutput`.
- `version()` → struct with `backend`, binary paths, `avifencVersion`,
  `avifdecVersion`, `platform`, `bundled`.
- `capabilities()` → struct describing supported formats and features.

## Error handling

Failures throw typed exceptions you can catch by `type`:

```cfml
try {
    avif.encode( source = src, destination = dest );
} catch ( "avif.binaryExecutionFailed" e ) {
    // e.detail contains the tool output
} catch ( "avif.timeout" e ) {
    // conversion exceeded the timeout
}
```

Types: `avif.unsupportedPlatform`, `avif.binaryNotFound`,
`avif.binaryExecutionFailed`, `avif.timeout`, `avif.invalidSource`,
`avif.invalidDestination`, `avif.unsupportedFormat`. Output is written atomically
(to a temp file, then moved on success), so a failed conversion never leaves a
partial destination file behind.

## Security notes

Binaries are executed directly with Java `ProcessBuilder` — **no shell** is
invoked — and every argument is passed as a discrete value, so filenames
containing spaces, `&`, `(`, `)` etc. are handled safely and cannot be
interpreted as flags or shell metacharacters. For untrusted uploads, keep the
`maxDimension` decode guard enabled.

## Known limitations

- **Windows x64 only** for now. On other platforms the module throws
  `avif.unsupportedPlatform` at load. macOS/Linux support is a matter of bundling
  the corresponding libavif binaries and extending the resolver.
- Animated AVIF is not supported.
- Crop/resize/flip are performed with `cfimage` (native ColdFusion image
  functions), not by the AVIF tools.

## Roadmap

- macOS (Apple Silicon, then Intel) and Linux (x64, then ARM64) support.
- 10-bit / HDR encode tests.
- Optional target-size encoding.

## Third-party binaries

This module bundles the libavif command-line tools. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for libavif / aom / dav1d license
and attribution details.

## License

Apache-2.0. See [LICENSE](LICENSE).

## About the author

Developed by [Angry Sam Productions](https://www.angrysam.com), a freelance web design and development company. We contribute to open source to strengthen the development
community. Get in touch to learn more or to hire us for your next project.
