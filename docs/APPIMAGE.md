# Building and testing the Rimution AppImage

The AppImage pipeline is in `.github/workflows/appimage.yml`. It builds a Release configuration, packages Qt/QML dependencies with linuxdeploy and its Qt plugin, runs a headless startup smoke test against both the native executable and the final AppImage, then uploads the AppImage and SHA-256 checksum as a GitHub Actions artifact.

## Trigger a build

- Push a change to `main` or a branch matching `feat/**`.
- Open **Actions → Build Rimution AppImage → Run workflow** to start one manually.
- Wait for the job to finish, then open its run page and download the artifact named `Rimution-AppImage-<commit-sha>`.

The artifact currently has a 14-day retention. This pipeline does not create a public GitHub Release or claim a stable product release.

## Test on CachyOS

Download and extract the Actions artifact ZIP. In the extracted directory:

```bash
chmod +x Rimution-x86_64.AppImage
sha256sum -c Rimution-x86_64.AppImage.sha256
./Rimution-x86_64.AppImage
```

If launching fails, run it from a terminal and capture all output:

```bash
./Rimution-x86_64.AppImage 2>&1 | tee rimution-startup.log
```

Confirm the window opens, playback moves the playhead, property adjustments create/update keyframes, and project save/open round-trips a `.rim` file. CI's offscreen smoke test only verifies packaging and startup; it does not replace these interactive checks on CachyOS.

## Known scope limits

Rimution remains an early 2D motion-graphics prototype. Video/audio import, clip editing, effects, masking, undo/redo, and video export are not implemented yet. Packaging as an AppImage does not mean those features exist.
