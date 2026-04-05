#Requires AutoHotkey v2.0
#SingleInstance Force

global Saved := Map()
global SharedHotkeyRegistryPath := A_ScriptDir "\hotkey_registry.ini"

fullscreenHotkey := GetSharedHotkey("fullscreen.toggle", "#z")
if fullscreenHotkey != "" {
    Hotkey(fullscreenHotkey, Func("ToggleFullscreenWindow"))
}

ToggleFullscreenWindow(*) {
    hwnd := WinGetID("A")
    if !hwnd
        return

    state := WinGetMinMax(hwnd)

    if (state = 1) {
        WinRestore(hwnd)
        Sleep 60

        if Saved.Has(hwnd) {
            r := Saved[hwnd]
            WinMove(r.x, r.y, r.w, r.h, hwnd)
        }
        return
    }

    if (state = -1) {
        WinRestore(hwnd)
        Sleep 60
    }

    x := y := w := h := 0
    WinGetPos(&x, &y, &w, &h, hwnd)
    Saved[hwnd] := { x: x, y: y, w: w, h: h }

    WinMaximize(hwnd)
}

GetSharedHotkey(id, fallback := "") {
    global SharedHotkeyRegistryPath

    if !FileExist(SharedHotkeyRegistryPath) {
        return fallback
    }

    count := IniRead(SharedHotkeyRegistryPath, "Meta", "count", "0") + 0
    Loop count {
        section := "Hotkey" . A_Index
        entryId := IniRead(SharedHotkeyRegistryPath, section, "id", "")
        if entryId != id {
            continue
        }

        return IniRead(SharedHotkeyRegistryPath, section, "hotkey", "")
    }

    return fallback
}
