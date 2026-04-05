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
- Support creating app hotkeys from a popup builder
- Support temporarily suspending the window-manager hotkeys
- Support a shared hotkey registry for repo-wide hotkey awareness

## Current App Hotkeys

- `Win+D` brings Discord to the main monitor. Press it again while Discord is focused on the main monitor to send it to the burner monitor tiled left.
- `Win+A` brings Claude to the main monitor. Press it again while Claude is focused on the main monitor to send it to the burner monitor tiled right.
- `Win+T` brings Windows Terminal to the main monitor. Press it again while Terminal is focused on the main monitor to send it to the burner monitor with its current floating placement preserved.
- `Win+P` brings Caido to the main monitor. Press it again while Caido is focused on the main monitor to switch back to the last window you were using.
- `Win+S` brings Firefox to the main monitor. Press it again while Firefox is focused on the main monitor to switch back to the last window you were using.

## How It Fits Together

This setup works like a desktop workspace mover:

- Hotkeyed apps can be stacked on top of each other on the main monitor so you can jump straight to the exact app you want.
- If you need space, you can send selected apps back to the burner monitor with the same hotkey.
- `Win+X` and `Win+C` move the focused window left or right across monitors while preserving its relative placement.
- `Win+R` pulls back the most recently pushed normal window.
- `Win+B` opens the app-hotkey builder for the currently focused window.
- `Win+;` toggles the window-manager hotkeys on and off.
- The order of normal pushed windows is remembered, so repeated pulls restore them in reverse order.

## App Hotkey Builder

- Press `Win+B` while focused on an app window.
- Choose the modifiers you want, then press the final key.
- Press `Esc` in the popup if you want to clear the selected key.
- Choose either `Main monitor config` or `Burner monitor config`.
- Click the `Hotkeys` button to open a hotkey browser popup with clickable hotkey cards.
- Clicking an app hotkey card loads that binding into the main editor so `Apply` updates that selected app cleanly.
- Clicking a shared hotkey card loads that shared action into the same editor so shared script bindings can be reassigned too.
- The builder warns immediately about conflicts.
- Click `Apply` to save the config and auto-reload the script.
- App hotkeys are stored in [window_manager_apps.ini](/C:/Users/jaady/OneDrive/Documentos/hotkeyable_windows/window_manager_apps.ini).
- Shared script hotkeys are stored in [hotkey_registry.ini](/C:/Users/jaady/OneDrive/Documentos/hotkeyable_windows/hotkey_registry.ini).

### `fullscreen.ahk`
Small helper script related to fullscreen window behavior.

### `kill.ahk`
Small helper script for closing/killing a target application or window.

## Notes

- Scripts are written for AutoHotkey v2.
- Managed app hotkeys are stored in [window_manager_apps.ini](/C:/Users/jaady/OneDrive/Documentos/hotkeyable_windows/window_manager_apps.ini).
- Shared repo-wide hotkey reservations are stored in [hotkey_registry.ini](/C:/Users/jaady/OneDrive/Documentos/hotkeyable_windows/hotkey_registry.ini).
- Core monitor behavior and hotkey logic live in [window_manager.ahk](/C:/Users/jaady/OneDrive/Documentos/hotkeyable_windows/window_manager.ahk).
