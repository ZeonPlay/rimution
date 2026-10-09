# AppImage packaging plan

AppImage packaging is intentionally a later milestone. Do not publish an AppImage until the app builds and passes the manual test plan on CachyOS.

The release pipeline should:

1. Build the application in a clean Linux environment.
2. Stage the executable, desktop entry, icon, Qt platform plugin, Quick Controls plugin, and every required QML import into an `AppDir`.
3. Use a maintained AppImage deployment tool/plugin compatible with the selected Qt 6 release.
4. Inspect the final AppDir for missing runtime libraries and QML modules.
5. Build the AppImage, make it executable, and test it outside the source/build tree on CachyOS.
6. Confirm project save/open works in the packaged build.

An AppImage built on a newer Linux baseline may not run on older distributions. Record the build environment and test against the intended baseline.
