# MVP manual test checklist

- [ ] Build with `cmake --preset dev` and `cmake --build --preset dev`.
- [ ] Start `./build/rimution`; confirm no QML module/import errors.
- [ ] Start playback; confirm the shape interpolates between keyframes.
- [ ] Move the playhead; confirm the preview and property values update.
- [ ] Change a property at a non-keyframed frame; confirm a keyframe is created.
- [ ] Add/update a keyframe; confirm its marker moves/appears on the timeline.
- [ ] Switch Indonesian/English; verify the visible labels update.
- [ ] Save a `.rim` project, close the application, then open the file again.
- [ ] Confirm project name, frame, FPS, language, and keyframes are restored.
- [ ] Try an invalid JSON file; verify an error is shown rather than a crash.

This is a test plan, not a claim that the checklist has passed.
