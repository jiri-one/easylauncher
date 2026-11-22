# Notes for agents

## Watch: pure Wayland on Linux

The Linux TV home runs through Xwayland (`GDK_BACKEND=x11`, see the README) because Flutter 3.50.1 presents through a synchronized Wayland subsurface and its raster thread spins in `wl_display_roundtrip` on labwc: [flutter#196529](https://github.com/flutter/flutter/issues/196529), fix in [PR #196945](https://github.com/flutter/flutter/pull/196945), still a draft on 2026-11-22. The software renderer is no way out; it aborts on Impeller text.

After every Flutter upgrade, check whether the stable release contains the fix. If it does, rebuild the Linux bundle, run it on the target machine without `GDK_BACKEND=x11`, confirm that it idles (it must not show up in `top`), then drop the variable from both READMEs and the labwc autostart line.
