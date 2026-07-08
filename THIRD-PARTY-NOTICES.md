# Third-Party Notices

This module (Apache-2.0) redistributes precompiled third-party binaries under
`bin/win-x64-1.4.2/`. Those binaries are licensed separately from the module's own
source code, as described below.

## Bundled binaries

| File | Project | Version |
|---|---|---|
| `avifenc.exe`, `avifdec.exe` | libavif | 1.4.2 |

Obtained from the official libavif release:
`https://github.com/AOMediaCodec/libavif/releases/tag/v1.4.2` (`windows-artifacts.zip`).
The Windows executables are statically linked and require no additional DLLs.

`avifenc --version` reports the exact component versions built in:

```
Version: 1.4.2 (dav1d [dec]:1.5.3, aom [enc]:3.14.1)
libyuv : available
```

## Component licenses

### libavif — BSD 2-Clause

```
Copyright 2019 Joe Drago. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this
   list of conditions and the following disclaimer in the documentation and/or
   other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES ... ARE DISCLAIMED. (Full text: https://github.com/AOMediaCodec/libavif/blob/main/LICENSE)
```

### aom (AV1 encoder, `[enc]`) — BSD 2-Clause + Alliance for Open Media Patent License 1.0

The AV1 codec library from the Alliance for Open Media is distributed under the
BSD 2-Clause license together with the **Alliance for Open Media Patent License
1.0**. Both must be honored when redistributing binaries that embed aom.
Full text: `https://aomedia.googlesource.com/aom/+/master/LICENSE` and
`https://aomedia.googlesource.com/aom/+/master/PATENTS`.

### dav1d (AV1 decoder, `[dec]`) — BSD 2-Clause

```
Copyright © 2018-2024, VideoLAN and dav1d authors. All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the BSD 2-Clause conditions are met.
Full text: https://code.videolan.org/videolan/dav1d/-/blob/master/COPYING
```

### libyuv — BSD 3-Clause

```
Copyright 2011 The LibYuv Project Authors. All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the BSD 3-Clause conditions are met.
Full text: https://chromium.googlesource.com/libyuv/libyuv/+/refs/heads/main/LICENSE
```

## Notes for maintainers

When bumping the bundled libavif version:

1. Update `bin/win-x64-<version>/` and `ModuleConfig.cfc::getBinPath()` together.
2. Re-run `avifenc --version` and update the component versions in this file.
3. Re-verify the aom / dav1d / libyuv versions and their license/patent texts.
