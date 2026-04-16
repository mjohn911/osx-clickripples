# Click Ripples

Tiny macOS menu-bar app that draws ripple circles at the mouse cursor whenever you click, so screen recordings and OBS captures can show click feedback.

## Download

Download the latest prebuilt app from GitHub Releases, then unzip `ClickRipples.app.zip` and open `ClickRipples.app`.

If macOS warns that the app is from an unidentified developer, use right-click > `Open` the first time. A future Developer ID signing/notarization setup would make that first-run experience smoother on other Macs.

## Build

```bash
cd /path/to/clickripples
./build.sh
```

## Run

```bash
open build/ClickRipples.app
```

When it launches, look for a `Ripples` menu-bar item. Use that menu to quit the app.
If clicks still do nothing, use the menu to open Accessibility Settings and enable `ClickRipples`, then relaunch it.

## Releases

This repo includes a GitHub Actions workflow that builds the app on macOS and attaches a zipped `ClickRipples.app` to GitHub Releases.

- Create a GitHub Release in the repository.
- GitHub Actions will build the app and upload `ClickRipples.app.zip` to that release.
- Power users can still build locally with `./build.sh`.

## Notes

- The overlay is click-through, so it will not block normal mouse input.
- If macOS asks for privacy permissions, allow the app so it can observe global mouse clicks.
- The menu includes `Show Test Ripple`, which is the fastest way to confirm the overlay is rendering even before permissions are sorted out.
- OBS display capture should see the ripple animation because it is rendered as a normal on-screen overlay window.
