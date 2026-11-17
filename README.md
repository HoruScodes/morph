# Morph

A small Mac menu-bar app. Drop files on its icon (or into its window) and convert or shrink them.
Everything happens on your Mac: no accounts, no network, no third-party code.

| Drop | You can |
| --- | --- |
| Images (HEIC, PNG, JPEG, TIFF, WebP, GIF) | Convert to JPG or PNG, make smaller, turn into a PDF |
| PDFs | Make smaller (text stays selectable), combine into one PDF, save pages as JPG |
| Video | Make smaller (720p MP4) |

Results are saved next to the first file you dropped. Nothing is overwritten: a second run
produces `photo 2.jpg`.

## Build and run

Needs macOS 15 or later and the Swift 6.2 toolchain (Command Line Tools are enough).

```sh
./scripts/build-app.sh      # builds build/Morph.app and ad-hoc signs it
open build/Morph.app
```

The first launch of an ad-hoc signed app may need right-click, Open.

## Test

```sh
./scripts/test.sh
```

With only the Command Line Tools installed, plain `swift test` cannot find Swift Testing, and
the script adds the flags that make it work. With Xcode installed it is the same as `swift test`.
The video test needs `ffmpeg` at `/opt/homebrew/bin/ffmpeg` and is skipped without it.

## Layout

- `Sources/ConvertKit` holds the conversion logic. `Action` is the table of what can be done,
  and `convert(_:inputs:progress:)` is the single entry point.
- `Sources/Morph` is the status item and popover.

## Site and launch video

- `site/` is the static marketing page (open `site/index.html`). Its screenshots are rendered from the app's own views: `swift build && .build/debug/Morph --shots site/images/app`.
- `video/` renders the launch video: `cd video && pnpm install && node render.mjs` writes `site/video/launch.mp4` and `poster.jpg`. It needs Google Chrome and ffmpeg.
- `site/download/Morph.zip` is the app the Download buttons serve. Rebuild it with `./scripts/build-app.sh && ditto -c -k --keepParent build/Morph.app site/download/Morph.zip`.
