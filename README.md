# hotkeyable_windows

A small collection of AutoHotkey scripts for window management and a few desktop shortcuts.

## Scripts

### `window_manager.ahk`
Main multi-monitor window manager.

- Push the focused window left or right across monitors
- Pull the most recently pushed window back
- Preserve relative window placement when moving between monitors
- Support quick re-tiling after a push
- Support app-specific hotkeys for bringing selected apps to the main monitor
- Support burner-monitor behavior for selected apps

## Current App Hotkeys

- `Win+D` brings Discord to the main monitor. Press it again while Discord is focused on the main monitor to send it to the burner monitor tiled left.
- `Win+R` brings Claude to the main monitor. Press it again while Claude is focused on the main monitor to send it to the burner monitor tiled right.
- `Win+T` brings Windows Terminal to the main monitor. Press it again while Terminal is focused on the main monitor to send it to the burner monitor with its current floating placement preserved.
- `Win+P` brings Caido to the main monitor. Press it again while Caido is focused on the main monitor to switch back to the last window you were using.
- `Win+S` brings Firefox to the main monitor. Press it again while Firefox is focused on the main monitor to switch back to the last window you were using.

## How It Fits Together

This setup works like a desktop workspace mover:

- Hotkeyed apps can be stacked on top of each other on the main monitor so you can jump straight to the exact app you want.
- If you need space, you can send selected apps back to the burner monitor with the same hotkey.
- `Win+X` and `Win+C` move the focused window left or right across monitors while preserving its relative placement.
- `Win+B` pulls back the most recently pushed normal window.
- The order of normal pushed windows is remembered, so repeated pulls restore them in reverse order.

### `fullscreen.ahk`
Small helper script related to fullscreen window behavior.

### `kill.ahk`
Small helper script for closing/killing a target application or window.

## Notes

- Scripts are written for AutoHotkey v2.
- The main configuration for app hotkeys and monitor behavior is at the top of `window_manager.ahk`.
