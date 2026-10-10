# Rimution

**Rimution** is an early, from-scratch desktop motion-graphics editor prototype for Linux. The first milestone focuses on 2D animation, a timeline, transform keyframes, and project files. It is not a replacement for After Effects yet, and it is not production-ready.

## Current prototype scope

- Local media bin with video, audio, and still-image imports.
- Video preview with playback, seeking, and embedded audio.
- A sequence video/image track (V1) and a separate audio overlay track (A1).
- Non-destructive source In/Out trimming, clip splitting at the playhead, clip reordering, and deletion.
- Audio clip placement, trim ranges, and volume control.
- MP4 export with H.264 video, AAC audio, optional layered audio, and progress reporting using FFmpeg.
- A motion-overlay layer with keyframed position, scale, rotation, and opacity.
- Project save/open with legacy version-1 compatibility, undo/redo snapshots, and Indonesian/English UI.

This is an early editor. It does not yet have full multi-track video compositing, transitions/effects, a waveform display, captions, proxy media, or a graph editor. The CI tests cover building, application startup, and a two-clip MP4 export; manual desktop use on CachyOS remains necessary.

## Build on CachyOS / Arch Linux

Install build tools and Qt 6:

```bash
sudo pacman -Syu
sudo pacman -S --needed base-devel cmake ninja gcc qt6-base qt6-declarative qt6-shadertools
```

Rimution targets Qt 6.4 or newer. Configure and compile:

```bash
cmake --preset dev
cmake --build --preset dev
./build/rimution
```

If CMake cannot find Qt 6, verify the installed package names and Qt CMake configuration paths on your system before adding third-party repositories.

## AppImage testing

The Release/AppImage packaging workflow is `.github/workflows/appimage.yml`. It creates a Release build, bundles Qt/QML dependencies, smoke-tests the packaged executable in a headless runner, and uploads the AppImage plus a SHA-256 checksum as a 14-day GitHub Actions artifact. See [docs/APPIMAGE.md](docs/APPIMAGE.md) for download and CachyOS test steps.

The CI startup test does not replace interactive GUI testing on CachyOS. Do not treat a CI artifact as a stable release until the project has passed those manual checks.

## Project files

A `.rim` file is JSON with a `format` field (`rimution-project`) and `formatVersion` (`1`). The project stores its name, FPS, current frame, duration, selected UI language, and keyframe list. Save is written through `QSaveFile` to avoid replacing a valid file with a partial write.

## Current status

This is a development prototype. The first acceptance pass should verify that the window starts, the object animates during playback, property edits create keyframes, and project save/open round-trips the keyframe data.

## Roadmap

1. Verify and stabilize the Qt/QML MVP.
2. Move project and animation data into dedicated engine classes with unit tests.
3. Add layer types (text, shape, image, video/audio clips).
4. Add easing curves and an interpolation/graph editor.
5. Add a render queue and FFmpeg-based export.
6. Finish AppImage packaging and test interactive behavior on CachyOS.
