# Third-party notices

VIDLOAD 1.0.0 includes the following unmodified command-line components as separate processes. They are not linked into the VIDLOAD executable.

## yt-dlp

- Version: 2026.08.19
- Source and releases: https://github.com/yt-dlp/yt-dlp
- License: The Unlicense

## FFmpeg

- Version: 9.0.1
- Build package: `@dfloresc/ffmpeg-macos-lgpl` 9.0.1-1
- Build source and redistribution notes: https://github.com/dfloresc/ffmpeg-macos-builds
- Upstream source: https://github.com/FFmpeg/FFmpeg/tree/n9.0.1
- License: LGPL-2.1-or-later for the FFmpeg build. The package contains the applicable FFmpeg and component license texts in `VIDLOADTools.bundle/<architecture>/LICENSES/`.

The distributed FFmpeg build uses macOS VideoToolbox for H.264 encoding and has GPL, nonfree and version-3-only components disabled. Codec patent licensing, if applicable, is separate from the copyright licences above.
