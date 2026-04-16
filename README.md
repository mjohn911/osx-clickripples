# Click Ripples

Tiny macOS menu-bar app that draws ripple circles at the mouse cursor whenever you click, so screen recordings and OBS captures can show click feedback.

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

## Notes

- The overlay is click-through, so it will not block normal mouse input.
- If macOS asks for privacy permissions, allow the app so it can observe global mouse clicks.
- The menu includes `Show Test Ripple`, which is the fastest way to confirm the overlay is rendering even before permissions are sorted out.
- OBS display capture should see the ripple animation because it is rendered as a normal on-screen overlay window.
