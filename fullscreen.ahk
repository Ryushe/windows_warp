#Requires AutoHotkey v2.0

; Stores prior placement per-window: Saved[hwnd] := {x, y, w, h}
global Saved := Map()

#z::  ; Win + Z
{
    hwnd := WinGetID("A")
    if !hwnd
        return

    state := WinGetMinMax(hwnd) ; -1=min, 0=normal, 1=max

    ; If currently maximized: restore, then re-apply saved rectangle (retile)
    if (state = 1) {
        WinRestore(hwnd)
        Sleep 60  ; let Windows finish restoring

        if Saved.Has(hwnd) {
            r := Saved[hwnd]
            ; Re-apply the exact rectangle (works for snapped/tiled too)
            WinMove(r.x, r.y, r.w, r.h, hwnd)
        }
        return
    }

    ; If minimized, restore first so we can capture real placement
    if (state = -1) {
        WinRestore(hwnd)
        Sleep 60
    }

    ; Save current rectangle BEFORE maximizing (this captures tiled/snap position)
    x := y := w := h := 0
    WinGetPos(&x, &y, &w, &h, hwnd)
    Saved[hwnd] := { x: x, y: y, w: w, h: h }

    WinMaximize(hwnd)
}