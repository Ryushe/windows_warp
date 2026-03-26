#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")

global MoveHistory := []
global LastPushAction := Map()
global ConfiguredAppPreviousWindow := Map()
global PushRetileDelayMs := 1000
global BurnerMonitorIndex := 2
global ConfiguredPullHotkeys := [
    ; General push behavior:
    ; - PushRetileDelayMs controls how quickly a follow-up X / C press
    ;   must happen to retile the just-moved window instead of moving it again.
    ; - Example: press Win+C, then quickly press X to snap that window to the
    ;   left half of the destination monitor.
    ; - BurnerMonitorIndex is the monitor used when a configured app hotkey is
    ;   pressed again while that app is already focused on the main monitor.
    ;
    ; App-specific pull hotkeys:
    ; 1. Copy one of the Map(...) lines below and paste it into this list.
    ; 2. Change "HOTKEY" to the shortcut you want, like "#1" for Win+1 or "^!s" for Ctrl+Alt+S.
    ; 3. Change "WINDOW_MATCH" to the app/window you want to pull to the main monitor.
    ; 4. Optional: add "mainMonitorAction" with one of these values:
    ;    "burner", "focus-last"
    ;    If omitted, the default is "burner".
    ; 5. Optional: add "burnerLayout" with one of these values:
    ;    "tile-left", "tile-right", "fullscreen", "float"
    ;    If omitted, the default is "float".
    ; 6. Reload the script after saving the file.
    ; 7. If the app is already focused on the main monitor:
    ;    - "burner" sends it to BurnerMonitorIndex using burnerLayout
    ;    - "focus-last" switches back to the last non-app window you were using
    ;
    ; How to find the right app/window name:
    ; - Best option: use Window Spy, which comes with AutoHotkey.
    ; - Open the app you want, launch Window Spy, then look for values like:
    ;   ahk_exe chrome.exe
    ;   ahk_exe Code.exe
    ;   ahk_class CabinetWClass
    ; - In most cases, "ahk_exe program.exe" is the easiest and most reliable match.
    ;
    ; Format: Map("hotkey", "HOTKEY", "match", "WINDOW_MATCH", "mainMonitorAction", "ACTION", "burnerLayout", "LAYOUT")
    ; Example entries:
    ; Map("hotkey", "#d", "match", "ahk_exe Discord.exe", "burnerLayout", "tile-left"),
    ; Map("hotkey", "#p", "match", "ahk_exe Caido.exe", "mainMonitorAction", "focus-last"),
    ; Map("hotkey", "#t", "match", "ahk_exe WindowsTerminal.exe", "burnerLayout", "float")

    Map("hotkey", "#d", "match", "ahk_exe Discord.exe", "burnerLayout", "tile-left"),
    Map("hotkey", "#p", "match", "ahk_exe Caido.exe", "mainMonitorAction", "focus-last"),
    Map("hotkey", "#r", "match", "ahk_exe Claude.exe", "burnerLayout", "tile-right"),
    Map("hotkey", "#s", "match", "ahk_exe firefox.exe", "mainMonitorAction", "focus-last"),
    Map("hotkey", "#t", "match", "ahk_exe WindowsTerminal.exe", "burnerLayout", "float"),

]

#x::MoveWindowDirection("left", false)
#c::MoveWindowDirection("right", false)
#^x::MoveWindowDirection("left", true)
#^c::MoveWindowDirection("right", true)
#b::PullMostRecentWindow()

RegisterConfiguredPullHotkeys()
RegisterRetileHotkeys()

RegisterConfiguredPullHotkeys() {
    global ConfiguredPullHotkeys

    for _, config in ConfiguredPullHotkeys {
        if !(config.Has("hotkey") && config.Has("match")) {
            continue
        }

        Hotkey(config["hotkey"], PullConfiguredWindow.Bind(config))
    }
}

RegisterRetileHotkeys() {
    Hotkey("*x", HandleRetileLeft, "Off")
    Hotkey("*c", HandleRetileRight, "Off")
    Hotkey("*#x", HandleRetileLeft, "Off")
    Hotkey("*#c", HandleRetileRight, "Off")
}

PullConfiguredWindow(config, *) {
    global ConfiguredAppPreviousWindow

    hwnd := FindConfiguredWindow(config["match"])
    if !hwnd {
        return
    }

    if WinGetMinMax("ahk_id " hwnd) = -1 {
        WinRestore("ahk_id " hwnd)
    }

    source := GetWindowPlacementInfo(hwnd)
    primary := GetMonitorByIndex(MonitorGetPrimary())
    burner := GetConfiguredBurnerMonitor(primary["index"])
    if !source || !primary {
        return
    }

    wasActive := WinActive("ahk_id " hwnd)
    if !wasActive {
        StoreConfiguredPreviousWindow(config, WinExist("A"), hwnd)
    }

    if source["monitorIndex"] = primary["index"] {
        WinActivate("ahk_id " hwnd)

        if wasActive {
            if GetMainMonitorAction(config) = "focus-last" {
                if FocusConfiguredPreviousWindow(config) {
                    return
                }
            } else if burner {
                ApplyBurnerLayout(hwnd, source, burner, GetBurnerLayout(config))
                return
            }

            return
        }

        CenterMouseOnMonitor(primary["index"])
        return
    }

    WinActivate("ahk_id " hwnd)
    ApplyRelativePlacement(hwnd, source, primary)

    CenterMouseOnMonitor(primary["index"])
}

MoveWindowDirection(direction, centerMouse) {
    global MoveHistory

    hwnd := WinExist("A")
    if !hwnd {
        return
    }

    if WinGetMinMax("ahk_id " hwnd) = -1 {
        WinRestore("ahk_id " hwnd)
    }

    source := GetWindowPlacementInfo(hwnd)
    if !source {
        return
    }

    target := GetAdjacentMonitor(source["monitorIndex"], direction)
    if !target {
        return
    }

    MoveHistory.Push(Map(
        "hwnd", hwnd,
        "state", source["state"],
        "x", source["x"],
        "y", source["y"],
        "w", source["w"],
        "h", source["h"]
    ))

    ApplyRelativePlacement(hwnd, source, target)
    RememberLastPushAction(hwnd)
    EnableRetileHotkeys()

    if centerMouse {
        CenterMouseOnMonitor(target["index"])
    }
}

HandleRetileLeft(*) {
    HandleRetileHotkey("left")
}

HandleRetileRight(*) {
    HandleRetileHotkey("right")
}

HandleRetileHotkey(direction) {
    global LastPushAction

    if !LastPushAction.Count || !LastPushAction.Has("hwnd") || !LastPushAction.Has("tick") {
        DisableRetileHotkeys()
        return
    }

    if (A_TickCount - LastPushAction["tick"]) > PushRetileDelayMs {
        ClearLastPushAction()
        DisableRetileHotkeys()
        return
    }

    hwnd := LastPushAction["hwnd"]
    if !WinExist("ahk_id " hwnd) {
        ClearLastPushAction()
        DisableRetileHotkeys()
        return
    }

    WinActivate("ahk_id " hwnd)
    TileWindowOnCurrentMonitor(hwnd, direction)
    ClearLastPushAction()
    DisableRetileHotkeys()
}

PullMostRecentWindow() {
    global MoveHistory

    while MoveHistory.Length > 0 {
        entry := MoveHistory.Pop()
        hwnd := entry["hwnd"]

        if !WinExist("ahk_id " hwnd) {
            continue
        }

        WinActivate("ahk_id " hwnd)

        if WinGetMinMax("ahk_id " hwnd) = -1 {
            WinRestore("ahk_id " hwnd)
        }

        RestoreWindowPlacement(hwnd, entry)

        CenterMouseOnMonitor(MonitorGetPrimary())
        return
    }
}

ApplyRelativePlacement(hwnd, source, target) {
    if source["state"] = 1 {
        WinRestore("ahk_id " hwnd)
    }

    targetWidth := target["workRight"] - target["workLeft"]
    targetHeight := target["workBottom"] - target["workTop"]

    newX := Round(target["workLeft"] + (source["relX"] * targetWidth))
    newY := Round(target["workTop"] + (source["relY"] * targetHeight))
    newW := Max(80, Round(source["relW"] * targetWidth))
    newH := Max(80, Round(source["relH"] * targetHeight))

    if newW > targetWidth {
        newW := targetWidth
    }
    if newH > targetHeight {
        newH := targetHeight
    }

    newX := Max(target["workLeft"], Min(newX, target["workRight"] - newW))
    newY := Max(target["workTop"], Min(newY, target["workBottom"] - newH))

    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    if source["state"] = 1 {
        WinMaximize("ahk_id " hwnd)
    }
}

GetWindowPlacementInfo(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return 0
    }

    monitors := GetOrderedMonitors()
    if monitors.Length = 0 {
        return 0
    }

    centerX := x + (w / 2)
    centerY := y + (h / 2)
    monitor := FindMonitorForPoint(centerX, centerY, monitors)
    if !monitor {
        return 0
    }

    workWidth := Max(1, monitor["workRight"] - monitor["workLeft"])
    workHeight := Max(1, monitor["workBottom"] - monitor["workTop"])
    state := WinGetMinMax("ahk_id " hwnd)

    if state = 1 {
        relX := 0
        relY := 0
        relW := 1
        relH := 1
    } else {
        relX := Clamp((x - monitor["workLeft"]) / workWidth, 0, 1)
        relY := Clamp((y - monitor["workTop"]) / workHeight, 0, 1)
        relW := Clamp(w / workWidth, 0.05, 1)
        relH := Clamp(h / workHeight, 0.05, 1)
    }

    return Map(
        "monitorIndex", monitor["index"],
        "state", state,
        "x", x,
        "y", y,
        "w", w,
        "h", h,
        "relX", relX,
        "relY", relY,
        "relW", relW,
        "relH", relH
    )
}

GetAdjacentMonitor(currentIndex, direction) {
    monitors := GetOrderedMonitors()
    if monitors.Length = 0 {
        return 0
    }

    currentPos := 0
    for index, monitor in monitors {
        if monitor["index"] = currentIndex {
            currentPos := index
            break
        }
    }

    if !currentPos {
        return 0
    }

    if direction = "left" {
        targetPos := currentPos - 1
        if targetPos < 1 {
            targetPos := monitors.Length
        }
    } else {
        targetPos := currentPos + 1
        if targetPos > monitors.Length {
            targetPos := 1
        }
    }

    return monitors[targetPos]
}

GetMonitorByIndex(targetIndex) {
    monitors := GetOrderedMonitors()
    for _, monitor in monitors {
        if monitor["index"] = targetIndex {
            return monitor
        }
    }

    return 0
}

GetConfiguredBurnerMonitor(primaryIndex) {
    global BurnerMonitorIndex

    burner := GetMonitorByIndex(BurnerMonitorIndex)
    if burner && burner["index"] != primaryIndex {
        return burner
    }

    monitors := GetOrderedMonitors()
    for _, monitor in monitors {
        if monitor["index"] != primaryIndex {
            return monitor
        }
    }

    return 0
}

GetOrderedMonitors() {
    monitors := []
    primaryIndex := MonitorGetPrimary()

    Loop MonitorGetCount() {
        index := A_Index
        MonitorGet(index, &left, &top, &right, &bottom)
        MonitorGetWorkArea(index, &workLeft, &workTop, &workRight, &workBottom)

        monitors.Push(Map(
            "index", index,
            "left", left,
            "top", top,
            "right", right,
            "bottom", bottom,
            "workLeft", workLeft,
            "workTop", workTop,
            "workRight", workRight,
            "workBottom", workBottom,
            "primary", index = primaryIndex
        ))
    }

    if monitors.Length > 1 {
        monitors := SortMonitors(monitors)
    }

    return monitors
}

SortMonitors(monitors) {
    count := monitors.Length
    Loop count - 1 {
        outer := A_Index
        Loop count - outer {
            inner := A_Index
            leftMonitor := monitors[inner]
            rightMonitor := monitors[inner + 1]

            if ((leftMonitor["left"] > rightMonitor["left"])
                || (leftMonitor["left"] = rightMonitor["left"] && leftMonitor["top"] > rightMonitor["top"])) {
                monitors[inner] := rightMonitor
                monitors[inner + 1] := leftMonitor
            }
        }
    }

    return monitors
}

FindMonitorForPoint(x, y, monitors) {
    for _, monitor in monitors {
        if x >= monitor["left"] && x < monitor["right"] && y >= monitor["top"] && y < monitor["bottom"] {
            return monitor
        }
    }

    closest := 0
    closestDistance := 0
    for _, monitor in monitors {
        centerX := monitor["left"] + ((monitor["right"] - monitor["left"]) / 2)
        centerY := monitor["top"] + ((monitor["bottom"] - monitor["top"]) / 2)
        distance := ((centerX - x) ** 2) + ((centerY - y) ** 2)

        if !closest || distance < closestDistance {
            closest := monitor
            closestDistance := distance
        }
    }

    return closest
}

FindConfiguredWindow(match) {
    if WinActive(match) {
        return WinExist("A")
    }

    hwnds := WinGetList(match)
    for _, hwnd in hwnds {
        if WinExist("ahk_id " hwnd) {
            return hwnd
        }
    }

    return 0
}

RestoreWindowPlacement(hwnd, placement) {
    if placement["state"] = 1 {
        WinRestore("ahk_id " hwnd)
    }

    WinMove(
        placement["x"],
        placement["y"],
        placement["w"],
        placement["h"],
        "ahk_id " hwnd
    )

    if placement["state"] = 1 {
        WinMaximize("ahk_id " hwnd)
    }
}

TileWindowOnCurrentMonitor(hwnd, direction) {
    source := GetWindowPlacementInfo(hwnd)
    if !source {
        return
    }

    monitor := GetMonitorByIndex(source["monitorIndex"])
    if !monitor {
        return
    }

    if source["state"] = 1 {
        WinRestore("ahk_id " hwnd)
    }

    workLeft := monitor["workLeft"]
    workTop := monitor["workTop"]
    workWidth := monitor["workRight"] - monitor["workLeft"]
    workHeight := monitor["workBottom"] - monitor["workTop"]
    halfWidth := Floor(workWidth / 2)

    if direction = "left" {
        newX := workLeft
        newW := halfWidth
    } else {
        newX := workLeft + halfWidth
        newW := workWidth - halfWidth
    }

    WinMove(newX, workTop, newW, workHeight, "ahk_id " hwnd)
}

ApplyBurnerLayout(hwnd, source, target, layout) {
    layout := StrLower(layout)

    if layout = "tile-left" {
        ApplyTileOnMonitor(hwnd, target, "left")
        return
    }

    if layout = "tile-right" {
        ApplyTileOnMonitor(hwnd, target, "right")
        return
    }

    if layout = "fullscreen" {
        ApplyFullscreenOnMonitor(hwnd, target)
        return
    }

    ApplyRelativePlacement(hwnd, source, target)
}

ApplyTileOnMonitor(hwnd, monitor, direction) {
    WinRestore("ahk_id " hwnd)

    workLeft := monitor["workLeft"]
    workTop := monitor["workTop"]
    workWidth := monitor["workRight"] - monitor["workLeft"]
    workHeight := monitor["workBottom"] - monitor["workTop"]
    halfWidth := Floor(workWidth / 2)

    if direction = "left" {
        newX := workLeft
        newW := halfWidth
    } else {
        newX := workLeft + halfWidth
        newW := workWidth - halfWidth
    }

    WinMove(newX, workTop, newW, workHeight, "ahk_id " hwnd)
}

ApplyFullscreenOnMonitor(hwnd, monitor) {
    WinRestore("ahk_id " hwnd)

    workLeft := monitor["workLeft"]
    workTop := monitor["workTop"]
    workWidth := monitor["workRight"] - monitor["workLeft"]
    workHeight := monitor["workBottom"] - monitor["workTop"]

    WinMove(workLeft, workTop, workWidth, workHeight, "ahk_id " hwnd)
    WinMaximize("ahk_id " hwnd)
}

GetBurnerLayout(config) {
    if config.Has("burnerLayout") {
        return config["burnerLayout"]
    }

    return "float"
}

GetMainMonitorAction(config) {
    if config.Has("mainMonitorAction") {
        return StrLower(config["mainMonitorAction"])
    }

    return "burner"
}

StoreConfiguredPreviousWindow(config, currentHwnd, targetHwnd) {
    global ConfiguredAppPreviousWindow

    if !currentHwnd || currentHwnd = targetHwnd {
        return
    }

    ConfiguredAppPreviousWindow[GetConfiguredAppKey(config)] := currentHwnd
}

FocusConfiguredPreviousWindow(config) {
    global ConfiguredAppPreviousWindow

    key := GetConfiguredAppKey(config)
    if !ConfiguredAppPreviousWindow.Has(key) {
        return false
    }

    hwnd := ConfiguredAppPreviousWindow[key]
    if !WinExist("ahk_id " hwnd) {
        ConfiguredAppPreviousWindow.Delete(key)
        return false
    }

    WinActivate("ahk_id " hwnd)
    return true
}

GetConfiguredAppKey(config) {
    return config.Has("hotkey") ? config["hotkey"] : config["match"]
}

GetMonitorIndexForWindow(hwnd, fallbackIndex := 1) {
    source := GetWindowPlacementInfo(hwnd)
    if !source {
        return fallbackIndex
    }

    return source["monitorIndex"]
}

RememberLastPushAction(hwnd) {
    global LastPushAction

    LastPushAction := Map(
        "hwnd", hwnd,
        "tick", A_TickCount
    )
}

EnableRetileHotkeys() {
    Hotkey("*x", "On")
    Hotkey("*c", "On")
    Hotkey("*#x", "On")
    Hotkey("*#c", "On")
    SetTimer(DisableRetileHotkeys, -PushRetileDelayMs)
}

DisableRetileHotkeys() {
    Hotkey("*x", "Off")
    Hotkey("*c", "Off")
    Hotkey("*#x", "Off")
    Hotkey("*#c", "Off")
}

ClearLastPushAction() {
    global LastPushAction

    LastPushAction := Map()
}

CenterMouseOnMonitor(index) {
    MonitorGetWorkArea(index, &left, &top, &right, &bottom)
    centerX := Round(left + ((right - left) / 2))
    centerY := Round(top + ((bottom - top) / 2))
    MouseMove(centerX, centerY, 0)
}

Clamp(value, minValue, maxValue) {
    if value < minValue {
        return minValue
    }
    if value > maxValue {
        return maxValue
    }
    return value
}
