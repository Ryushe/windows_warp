#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")

global MoveHistory := []
global LastPushAction := Map()
global ConfiguredAppPreviousWindow := Map()
global ConfiguredPullHotkeyState := Map()
global ConfiguredPullBuilderState := Map()
global PushRetileDelayMs := 1000
global ConfiguredPullHoldDelayMs := 400
global BurnerMonitorIndex := 2
global ConfiguredPullConfigPath := A_ScriptDir "\window_manager_apps.ini"
global SharedHotkeyRegistryPath := A_ScriptDir "\hotkey_registry.ini"
global WorkspaceOpenerConfigPath := A_ScriptDir "\workspace_openers.ini"
global SharedHotkeyRegistry := InitializeSharedHotkeyRegistry()
global ConfiguredPullHotkeys := InitializeConfiguredPullHotkeys()
global WorkspaceOpenerProfiles := LoadWorkspaceOpenerProfiles()

#x::MoveWindowDirection("left", false)
#c::MoveWindowDirection("right", false)
#^x::MoveWindowDirection("left", true)
#^c::MoveWindowDirection("right", true)
#b::OpenConfiguredHotkeyBuilder()
#o::OpenWorkspaceOpenerBrowser()
#r::PullMostRecentWindow()
#SuspendExempt
#;::ToggleWindowManagerSuspend()
#SuspendExempt False

RegisterConfiguredPullHotkeys()
RegisterRetileHotkeys()
OnMessage(0x100, HandleConfiguredPullBuilderKeyDown)
OnMessage(0x200, HandleConfiguredPullBuilderMouseMove)
OnMessage(0x20A, HandleWindowManagerMouseWheel)

RegisterConfiguredPullHotkeys() {
    global ConfiguredPullHotkeys

    for _, config in ConfiguredPullHotkeys {
        if !(config.Has("hotkey") && config.Has("match")) {
            continue
        }

        Hotkey(config["hotkey"], HandleConfiguredPullHotkeyDown.Bind(config))
    }
}

RegisterRetileHotkeys() {
    Hotkey("*x", HandleRetileLeft, "Off")
    Hotkey("*c", HandleRetileRight, "Off")
    Hotkey("*#x", HandleRetileLeft, "Off")
    Hotkey("*#c", HandleRetileRight, "Off")
}

InitializeSharedHotkeyRegistry() {
    global SharedHotkeyRegistryPath

    if !FileExist(SharedHotkeyRegistryPath) {
        SaveSharedHotkeyRegistry(DefaultSharedHotkeyRegistry())
    }

    registry := LoadSharedHotkeyRegistry()
    if registry.Length = 0 {
        registry := DefaultSharedHotkeyRegistry()
        SaveSharedHotkeyRegistry(registry)
    }

    return registry
}

InitializeConfiguredPullHotkeys() {
    global ConfiguredPullConfigPath

    if !FileExist(ConfiguredPullConfigPath) {
        SaveConfiguredPullHotkeys(DefaultConfiguredPullHotkeys())
    }

    configs := LoadConfiguredPullHotkeys()
    if configs.Length = 0 {
        configs := DefaultConfiguredPullHotkeys()
        SaveConfiguredPullHotkeys(configs)
    }

    return configs
}

DefaultSharedHotkeyRegistry() {
    return [
        Map("id", "wm.move-left", "hotkey", "#x", "action", "Move window left", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.move-right", "hotkey", "#c", "action", "Move window right", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.move-left-center", "hotkey", "#^x", "action", "Move window left and center mouse", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.move-right-center", "hotkey", "#^c", "action", "Move window right and center mouse", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.open-builder", "hotkey", "#b", "action", "Open hotkey builder", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.open-opener", "hotkey", "#o", "action", "Open workspace opener", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.pull-recent", "hotkey", "#r", "action", "Pull most recent window", "source", "script", "script", "window_manager.ahk"),
        Map("id", "wm.toggle-suspend", "hotkey", "#;", "action", "Toggle window manager hotkeys", "source", "script", "script", "window_manager.ahk"),
        Map("id", "fullscreen.toggle", "hotkey", "#z", "action", "Toggle fullscreen helper", "source", "script", "script", "fullscreen.ahk"),
        Map("id", "kill.close-active", "hotkey", "#q", "action", "Close active window", "source", "script", "script", "kill.ahk")
    ]
}

LoadSharedHotkeyRegistry() {
    global SharedHotkeyRegistryPath

    registry := []
    if !FileExist(SharedHotkeyRegistryPath) {
        return registry
    }

    count := IniRead(SharedHotkeyRegistryPath, "Meta", "count", "0") + 0
    Loop count {
        section := "Hotkey" . A_Index
        id := IniRead(SharedHotkeyRegistryPath, section, "id", "")
        hotkey := IniRead(SharedHotkeyRegistryPath, section, "hotkey", "")
        action := IniRead(SharedHotkeyRegistryPath, section, "action", "")
        if action = "" {
            continue
        }

        entry := Map(
            "id", id != "" ? id : action,
            "hotkey", hotkey,
            "action", action,
            "source", IniRead(SharedHotkeyRegistryPath, section, "source", "script"),
            "script", IniRead(SharedHotkeyRegistryPath, section, "script", "")
        )
        disabledHotkey := IniRead(SharedHotkeyRegistryPath, section, "disabledHotkey", "")
        if disabledHotkey != "" {
            entry["disabledHotkey"] := disabledHotkey
        }
        registry.Push(entry)
    }

    return registry
}

SaveSharedHotkeyRegistry(registry) {
    global SharedHotkeyRegistryPath

    if FileExist(SharedHotkeyRegistryPath) {
        FileDelete(SharedHotkeyRegistryPath)
    }

    IniWrite(registry.Length, SharedHotkeyRegistryPath, "Meta", "count")
    for index, entry in registry {
        section := "Hotkey" . index
        IniWrite(entry.Has("id") ? entry["id"] : "", SharedHotkeyRegistryPath, section, "id")
        IniWrite(entry["hotkey"], SharedHotkeyRegistryPath, section, "hotkey")
        IniWrite(entry["action"], SharedHotkeyRegistryPath, section, "action")
        IniWrite(entry.Has("source") ? entry["source"] : "script", SharedHotkeyRegistryPath, section, "source")
        IniWrite(entry.Has("script") ? entry["script"] : "", SharedHotkeyRegistryPath, section, "script")
        IniWrite(entry.Has("disabledHotkey") ? entry["disabledHotkey"] : "", SharedHotkeyRegistryPath, section, "disabledHotkey")
    }
}

GetSharedHotkey(id, fallback := "") {
    entry := FindSharedRegistryEntryById(id)
    if entry {
        return entry["hotkey"]
    }

    return fallback
}

DefaultConfiguredPullHotkeys() {
    return [
        Map("hotkey", "#d", "match", "ahk_exe Discord.exe", "label", "Discord", "mainMonitorAction", "burner", "burnerLayout", "tile-left"),
        Map("hotkey", "#p", "match", "ahk_exe Caido.exe", "label", "Caido", "mainMonitorAction", "focus-last"),
        Map("hotkey", "#a", "match", "ahk_exe Claude.exe", "label", "Claude", "mainMonitorAction", "burner", "burnerLayout", "tile-right"),
        Map("hotkey", "#s", "match", "ahk_exe firefox.exe", "label", "Firefox", "mainMonitorAction", "focus-last"),
        Map("hotkey", "#t", "match", "ahk_exe WindowsTerminal.exe", "label", "Windows Terminal", "mainMonitorAction", "burner", "burnerLayout", "float"),
    ]
}

LoadConfiguredPullHotkeys() {
    global ConfiguredPullConfigPath

    configs := []
    count := IniRead(ConfiguredPullConfigPath, "Meta", "count", "0") + 0

    Loop count {
        section := "App" . A_Index
        hotkey := IniRead(ConfiguredPullConfigPath, section, "hotkey", "")
        match := IniRead(ConfiguredPullConfigPath, section, "match", "")
        if hotkey = "" || match = "" {
            continue
        }

        config := Map(
            "hotkey", hotkey,
            "match", match
        )

        label := IniRead(ConfiguredPullConfigPath, section, "label", "")
        mainMonitorAction := IniRead(ConfiguredPullConfigPath, section, "mainMonitorAction", "")
        burnerLayout := IniRead(ConfiguredPullConfigPath, section, "burnerLayout", "")

        if label != "" {
            config["label"] := label
        }
        if mainMonitorAction != "" {
            config["mainMonitorAction"] := mainMonitorAction
        }
        if burnerLayout != "" {
            config["burnerLayout"] := burnerLayout
        }

        configs.Push(config)
    }

    return configs
}

SaveConfiguredPullHotkeys(configs) {
    global ConfiguredPullConfigPath

    if FileExist(ConfiguredPullConfigPath) {
        FileDelete(ConfiguredPullConfigPath)
    }

    IniWrite(configs.Length, ConfiguredPullConfigPath, "Meta", "count")
    for index, config in configs {
        section := "App" . index
        IniWrite(config["hotkey"], ConfiguredPullConfigPath, section, "hotkey")
        IniWrite(config["match"], ConfiguredPullConfigPath, section, "match")
        IniWrite(config.Has("label") ? config["label"] : "", ConfiguredPullConfigPath, section, "label")
        IniWrite(config.Has("mainMonitorAction") ? config["mainMonitorAction"] : "", ConfiguredPullConfigPath, section, "mainMonitorAction")
        IniWrite(config.Has("burnerLayout") ? config["burnerLayout"] : "", ConfiguredPullConfigPath, section, "burnerLayout")
    }
}

LoadWorkspaceOpenerProfiles() {
    global WorkspaceOpenerConfigPath

    profiles := []
    if !FileExist(WorkspaceOpenerConfigPath) {
        return profiles
    }

    count := IniRead(WorkspaceOpenerConfigPath, "Meta", "count", "0") + 0
    Loop count {
        profileSection := "Profile" . A_Index
        profileId := IniRead(WorkspaceOpenerConfigPath, profileSection, "id", "")
        name := IniRead(WorkspaceOpenerConfigPath, profileSection, "name", "")
        itemCount := IniRead(WorkspaceOpenerConfigPath, profileSection, "itemCount", "0") + 0
        if name = "" {
            continue
        }

        items := []
        Loop itemCount {
            itemSection := profileSection . "Item" . A_Index
            processName := IniRead(WorkspaceOpenerConfigPath, itemSection, "processName", "")
            path := IniRead(WorkspaceOpenerConfigPath, itemSection, "path", "")
            title := IniRead(WorkspaceOpenerConfigPath, itemSection, "title", "")
            label := IniRead(WorkspaceOpenerConfigPath, itemSection, "label", "")
            terminalCommand := IniRead(WorkspaceOpenerConfigPath, itemSection, "terminalCommand", "")
            terminalShell := IniRead(WorkspaceOpenerConfigPath, itemSection, "terminalShell", "")
            launchKind := IniRead(WorkspaceOpenerConfigPath, itemSection, "launchKind", "")
            shellKind := IniRead(WorkspaceOpenerConfigPath, itemSection, "shellKind", "")
            wslDistro := IniRead(WorkspaceOpenerConfigPath, itemSection, "wslDistro", "")
            profileName := IniRead(WorkspaceOpenerConfigPath, itemSection, "profileName", "")
            promptIdentity := IniRead(WorkspaceOpenerConfigPath, itemSection, "promptIdentity", "")
            x := IniRead(WorkspaceOpenerConfigPath, itemSection, "x", "")
            y := IniRead(WorkspaceOpenerConfigPath, itemSection, "y", "")
            w := IniRead(WorkspaceOpenerConfigPath, itemSection, "w", "")
            h := IniRead(WorkspaceOpenerConfigPath, itemSection, "h", "")
            state := IniRead(WorkspaceOpenerConfigPath, itemSection, "state", "0") + 0
            monitorIndex := IniRead(WorkspaceOpenerConfigPath, itemSection, "monitorIndex", "1") + 0
            if processName = "" || x = "" || y = "" || w = "" || h = "" {
                continue
            }

            items.Push(Map(
                "processName", processName,
                "path", path,
                "title", title,
                "label", label != "" ? label : title,
                "launchKind", launchKind,
                "shellKind", shellKind != "" ? shellKind : terminalShell,
                "wslDistro", wslDistro,
                "profileName", profileName,
                "promptIdentity", promptIdentity,
                "x", x + 0,
                "y", y + 0,
                "w", w + 0,
                "h", h + 0,
                "state", state,
                "monitorIndex", monitorIndex
            ))

            item := items[items.Length]
            MigrateWorkspaceOpenerItem(item, terminalCommand)
        }

        profiles.Push(Map(
            "id", profileId != "" ? profileId : "workspace-" . A_Index,
            "name", name,
            "items", items
        ))
    }

    return profiles
}

SaveWorkspaceOpenerProfiles(profiles) {
    global WorkspaceOpenerConfigPath

    if FileExist(WorkspaceOpenerConfigPath) {
        FileDelete(WorkspaceOpenerConfigPath)
    }

    IniWrite(profiles.Length, WorkspaceOpenerConfigPath, "Meta", "count")
    for profileIndex, profile in profiles {
        profileSection := "Profile" . profileIndex
        IniWrite(profile.Has("id") ? profile["id"] : "workspace-" . profileIndex, WorkspaceOpenerConfigPath, profileSection, "id")
        IniWrite(profile["name"], WorkspaceOpenerConfigPath, profileSection, "name")
        IniWrite(profile["items"].Length, WorkspaceOpenerConfigPath, profileSection, "itemCount")

        for itemIndex, item in profile["items"] {
            itemSection := profileSection . "Item" . itemIndex
            IniWrite(item["processName"], WorkspaceOpenerConfigPath, itemSection, "processName")
            IniWrite(item.Has("path") ? item["path"] : "", WorkspaceOpenerConfigPath, itemSection, "path")
            IniWrite(item.Has("title") ? item["title"] : "", WorkspaceOpenerConfigPath, itemSection, "title")
            IniWrite(item.Has("label") ? item["label"] : "", WorkspaceOpenerConfigPath, itemSection, "label")
            IniWrite("", WorkspaceOpenerConfigPath, itemSection, "terminalCommand")
            IniWrite(item.Has("shellKind") ? item["shellKind"] : "", WorkspaceOpenerConfigPath, itemSection, "terminalShell")
            IniWrite(item.Has("launchKind") ? item["launchKind"] : "", WorkspaceOpenerConfigPath, itemSection, "launchKind")
            IniWrite(item.Has("shellKind") ? item["shellKind"] : "", WorkspaceOpenerConfigPath, itemSection, "shellKind")
            IniWrite(item.Has("wslDistro") ? item["wslDistro"] : "", WorkspaceOpenerConfigPath, itemSection, "wslDistro")
            IniWrite(item.Has("profileName") ? item["profileName"] : "", WorkspaceOpenerConfigPath, itemSection, "profileName")
            IniWrite(item.Has("promptIdentity") ? item["promptIdentity"] : "", WorkspaceOpenerConfigPath, itemSection, "promptIdentity")
            IniWrite(item["x"], WorkspaceOpenerConfigPath, itemSection, "x")
            IniWrite(item["y"], WorkspaceOpenerConfigPath, itemSection, "y")
            IniWrite(item["w"], WorkspaceOpenerConfigPath, itemSection, "w")
            IniWrite(item["h"], WorkspaceOpenerConfigPath, itemSection, "h")
            IniWrite(item.Has("state") ? item["state"] : 0, WorkspaceOpenerConfigPath, itemSection, "state")
            IniWrite(item.Has("monitorIndex") ? item["monitorIndex"] : 1, WorkspaceOpenerConfigPath, itemSection, "monitorIndex")
        }
    }
}

MigrateWorkspaceOpenerItem(item, legacyTerminalCommand := "") {
    processName := StrLower(item.Has("processName") ? item["processName"] : "")
    path := item.Has("path") ? item["path"] : ""

    if !item.Has("launchKind") || item["launchKind"] = "" {
        if processName = "windowsterminal.exe" {
            item["launchKind"] := "windows-terminal"
        } else if path != "" && IsPackagedAppPath(path) {
            item["launchKind"] := "packaged-app"
        } else if path != "" {
            item["launchKind"] := "app-path"
        }
    }

    if processName = "windowsterminal.exe" {
        if legacyTerminalCommand != "" {
            ApplyLegacyTerminalCommandToItem(item, legacyTerminalCommand)
        }
        NormalizeTerminalLaunchItem(item)
    }
}

ApplyLegacyTerminalCommandToItem(item, legacyTerminalCommand) {
    command := Trim(legacyTerminalCommand)
    lowerCommand := StrLower(command)
    if command = "" {
        return
    }

    if RegExMatch(command, 'i)wsl\.exe\s+-d\s+"([^"]+)"', &match) {
        item["shellKind"] := "wsl"
        item["wslDistro"] := match[1]
        return
    }
    if lowerCommand = "wsl.exe" {
        item["shellKind"] := "wsl"
        return
    }
    if InStr(lowerCommand, "powershell.exe") {
        item["shellKind"] := "powershell"
        return
    }
    if InStr(lowerCommand, "pwsh.exe") {
        item["shellKind"] := "pwsh"
        return
    }
    if InStr(lowerCommand, "cmd.exe") {
        item["shellKind"] := "cmd"
        return
    }
}

NormalizeTerminalLaunchItem(item) {
    item["launchKind"] := "windows-terminal"

    if item.Has("shellKind") {
        shellKind := StrLower(Trim(item["shellKind"]))
        item["shellKind"] := shellKind
    } else {
        shellKind := ""
    }

    if (!item.Has("shellKind") || item["shellKind"] = "") && item.Has("title") {
        shellSpec := InferWindowsTerminalShellSpec(item["title"])
        if shellSpec {
            item["shellKind"] := GetTerminalShellKind(shellSpec["shell"])
            if shellSpec.Has("distro") && shellSpec["distro"] != "" {
                item["wslDistro"] := shellSpec["distro"]
            }
            if shellSpec.Has("profileName") && shellSpec["profileName"] != "" {
                item["profileName"] := shellSpec["profileName"]
            }
            if shellSpec.Has("promptIdentity") && shellSpec["promptIdentity"] != "" {
                item["promptIdentity"] := shellSpec["promptIdentity"]
            }
        }
    }

    if (!item.Has("profileName") || item["profileName"] = "") && item.Has("title") {
        profileName := GetWindowsTerminalProfileName(item["title"])
        if profileName != "" {
            item["profileName"] := profileName
        }
    }
}

EnsureWorkspaceOpenerState() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        ConfiguredPullBuilderState := Map()
    }

    defaults := Map(
        "uiTheme", GetUiTheme(),
        "openerGui", 0,
        "openerGuiHwnd", 0,
        "openerSelectedId", "",
        "openerPageIndex", 1,
        "openerPages", [],
        "openerPageLabel", 0,
        "openerPrevButton", 0,
        "openerNextButton", 0,
        "openerDetailsText", 0,
        "openerDynamicControls", [],
        "openerCardControls", []
    )

    for key, value in defaults {
        if !ConfiguredPullBuilderState.Has(key) {
            ConfiguredPullBuilderState[key] := value
        }
    }
}

OpenConfiguredHotkeyBuilder(*) {
    global ConfiguredPullBuilderState

    windowInfo := GetActiveConfiguredWindowInfo()
    if !windowInfo {
        return
    }

    CloseConfiguredPullBuilder()
    uiTheme := GetUiTheme()

    builderGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Hotkey Editor")
    builderGui.SetFont("s10", "Segoe UI")
    builderGui.BackColor := uiTheme["surface"]
    builderGui.MarginX := 0
    builderGui.MarginY := 0
    builderGui.OnEvent("Close", (*) => CloseConfiguredPullBuilder())
    builderGui.OnEvent("Escape", (*) => CloseConfiguredPullBuilder())

    left := 18
    contentWidth := 520
    headerBar := builderGui.AddText("x0 y0 w516 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(builderGui))
    builderGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := builderGui.AddText("x14 y9 w440 c" . uiTheme["headerText"], "Hotkey Editor")
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(builderGui))
    closeButton := builderGui.AddText("x522 y5 w26 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")
    closeButton.OnEvent("Click", (*) => CloseConfiguredPullBuilder())

    builderGui.SetFont("s9", "Segoe UI")
    builderGui.AddText(Format("x{} y58 w{} c{}", left, contentWidth, uiTheme["muted"]), "Set the hotkey, choose the behavior, and apply. Changes reload the script automatically.")

    builderGui.AddText(Format("x{} y98 w{} c{}", left, contentWidth, uiTheme["section"]), "TARGET")
    appLabelText := builderGui.AddText(Format("x{} y130 w{} c{}", left, contentWidth, uiTheme["text"]), windowInfo["label"])
    appMatchText := builderGui.AddText(Format("x{} y166 w{} c{}", left, contentWidth, uiTheme["muted"]), windowInfo["match"])

    builderGui.AddText(Format("x{} y206 w{} c{}", left, contentWidth, uiTheme["section"]), "HOTKEY")
    selectedKeyBox := builderGui.AddText(Format("x{} y238 w240 h36 +Border Background{}", left, uiTheme["input"]), "")
    selectedKeyText := builderGui.AddText(Format("x{} y246 w240 h20 Center c{} BackgroundTrans", left, uiTheme["text"]), "")
    hotkeyHintText := builderGui.AddText(Format("x{} y244 w260 c{}", left + 256, uiTheme["muted"]), "Press any key to begin. Press Esc to close.")
    conflictText := builderGui.AddText(Format("x{} y278 w{} c{} Hidden", left, contentWidth, uiTheme["danger"]), "")

    winCheckbox := builderGui.AddCheckBox(Format("x{} y309 w18 h18 Checked", left), "")
    winLabel := builderGui.AddText(Format("x{} y309 c{}", left + 28, uiTheme["text"]), "Win")
    winLabel.OnEvent("Click", (*) => ToggleBuilderCheckbox("winCheckbox"))
    ctrlCheckbox := builderGui.AddCheckBox(Format("x{} y309 w18 h18", left + 92), "")
    ctrlLabel := builderGui.AddText(Format("x{} y309 c{}", left + 120, uiTheme["text"]), "Ctrl")
    ctrlLabel.OnEvent("Click", (*) => ToggleBuilderCheckbox("ctrlCheckbox"))
    altCheckbox := builderGui.AddCheckBox(Format("x{} y309 w18 h18", left + 180), "")
    altLabel := builderGui.AddText(Format("x{} y309 c{}", left + 208, uiTheme["text"]), "Alt")
    altLabel.OnEvent("Click", (*) => ToggleBuilderCheckbox("altCheckbox"))
    shiftCheckbox := builderGui.AddCheckBox(Format("x{} y309 w18 h18", left + 252), "")
    shiftLabel := builderGui.AddText(Format("x{} y309 c{}", left + 280, uiTheme["text"]), "Shift")
    shiftLabel.OnEvent("Click", (*) => ToggleBuilderCheckbox("shiftCheckbox"))

    builderGui.AddText(Format("x{} y350 w{} c{}", left, contentWidth, uiTheme["section"]), "BEHAVIOR")
    mainRadio := builderGui.AddRadio(Format("x{} y378 w150 h22 Checked c{}", left, uiTheme["text"]), "Main monitor config")
    mainRadio.OnEvent("Click", (*) => SelectBuilderBehavior("main"))
    burnerRadio := builderGui.AddRadio(Format("x{} y378 w170 h22 c{}", left + 188, uiTheme["text"]), "Burner monitor config")
    burnerRadio.OnEvent("Click", (*) => SelectBuilderBehavior("burner"))
    helpText := builderGui.AddText(Format("x{} y414 w{} h34 c{}", left, contentWidth, uiTheme["muted"]), "Hover a config type to see what it does.")

    applyButton := builderGui.AddButton(Format("x{} y472 w96 h30 Default", left), "Apply")
    cancelButton := builderGui.AddButton(Format("x{} y472 w96 h30", left + 108), "Cancel")
    hotkeysButton := builderGui.AddButton(Format("x{} y472 w96 h30", left + 216), "Hotkeys")
    openerButton := builderGui.AddButton(Format("x{} y472 w96 h30", left + 324), "Opener")
    applyButton.OnEvent("Click", (*) => SaveConfiguredPullBuilder())
    cancelButton.OnEvent("Click", (*) => CloseConfiguredPullBuilder())
    hotkeysButton.OnEvent("Click", (*) => ToggleHotkeyKeyboardViewer())
    openerButton.OnEvent("Click", (*) => OpenWorkspaceOpenerBrowser())

    ConfiguredPullBuilderState := Map(
        "gui", builderGui,
        "guiHwnd", builderGui.Hwnd,
        "uiTheme", uiTheme,
        "appLabelText", appLabelText,
        "appMatchText", appMatchText,
        "selectedKeyBox", selectedKeyBox,
        "selectedKeyText", selectedKeyText,
        "hotkeyHintText", hotkeyHintText,
        "conflictText", conflictText,
        "helpText", helpText,
        "applyButton", applyButton,
        "cancelButton", cancelButton,
        "hotkeysButton", hotkeysButton,
        "openerButton", openerButton,
        "closeButton", closeButton,
        "keyboardGui", 0,
        "keyboardGuiHwnd", 0,
        "keyboardCloseButton", 0,
        "keyboardPageIndex", 1,
        "keyboardPages", [],
        "keyboardRenderedControls", [],
        "keyboardPageLabel", 0,
        "keyboardPrevButton", 0,
        "keyboardNextButton", 0,
        "openerGui", 0,
        "openerGuiHwnd", 0,
        "openerSelectedId", "",
        "openerPageIndex", 1,
        "openerPages", [],
        "openerPageLabel", 0,
        "openerPrevButton", 0,
        "openerNextButton", 0,
        "openerDetailsText", 0,
        "captureReadyAt", A_TickCount + 200,
        "winCheckbox", winCheckbox,
        "ctrlCheckbox", ctrlCheckbox,
        "altCheckbox", altCheckbox,
        "shiftCheckbox", shiftCheckbox,
        "winLabel", winLabel,
        "ctrlLabel", ctrlLabel,
        "altLabel", altLabel,
        "shiftLabel", shiftLabel,
        "mainRadio", mainRadio,
        "burnerRadio", burnerRadio,
        "windowInfo", windowInfo,
        "selectedHotkey", "",
        "selectedHotkeyDisplay", "",
        "editingKind", "app",
        "editingSharedId", "",
        "hoverDescriptions", Map(
            mainRadio.Hwnd, "Main monitor config: the hotkey brings the app to the main monitor, and pressing it again while it is focused there switches back to your previous app.",
            burnerRadio.Hwnd, "Burner monitor config: the hotkey brings the app to the main monitor, and pressing it again while it is focused there sends it back to the burner monitor.",
        ),
        "defaultHoverText", "Hover a config type to see what it does."
    )

    SetConfiguredPullBuilderEditingMode("app", windowInfo)
    LoadActiveWindowConfigIntoBuilder(windowInfo)
    builderGui.Show("w560 h526 Center")
    winCheckbox.Focus()
}

CloseConfiguredPullBuilder() {
    global ConfiguredPullBuilderState

    CloseHotkeyKeyboardViewer()
    CloseWorkspaceOpenerBrowser()

    if ConfiguredPullBuilderState.Count && ConfiguredPullBuilderState.Has("gui") {
        try ConfiguredPullBuilderState["gui"].Destroy()
    }

    ConfiguredPullBuilderState := Map()
}

HandleConfiguredPullBuilderKeyDown(wParam, lParam, msg, hwnd) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    activeHwnd := WinExist("A")
    keyName := NormalizeBuilderKeyName(wParam, lParam)

    if ConfiguredPullBuilderState["keyboardGuiHwnd"] && activeHwnd = ConfiguredPullBuilderState["keyboardGuiHwnd"] {
        if keyName = "Delete" {
            PerformSelectedHotkeyViewerAction()
            return 0
        }
        if keyName = "Escape" {
            CloseHotkeyKeyboardViewer()
            return 0
        }
        return
    }

    if ConfiguredPullBuilderState["openerGuiHwnd"] && activeHwnd = ConfiguredPullBuilderState["openerGuiHwnd"] {
        if keyName = "Delete" {
            DeleteSelectedWorkspaceOpener()
            return 0
        }
        if keyName = "Escape" {
            CloseWorkspaceOpenerBrowser()
            return 0
        }
        return
    }

    if activeHwnd != ConfiguredPullBuilderState["guiHwnd"] {
        return
    }

    if A_TickCount < ConfiguredPullBuilderState["captureReadyAt"] {
        return 0
    }

    if keyName = "" {
        return 0
    }

    if keyName = "Left" || keyName = "Right" {
        if ConfiguredPullBuilderState["selectedHotkey"] != "" && ConfiguredPullBuilderState["editingKind"] = "app" {
            SelectBuilderBehavior(keyName = "Left" ? "main" : "burner")
            ConfiguredPullBuilderState["applyButton"].Focus()
        }
        return 0
    }

    if keyName = "Enter" {
        if ConfiguredPullBuilderState["selectedHotkey"] != "" {
            ConfiguredPullBuilderState["applyButton"].Focus()
        }
        return
    }

    if keyName = "Escape" {
        CloseConfiguredPullBuilder()
        return 0
    }

    if IsBuilderModifierKey(keyName) {
        return 0
    }

    combo := BuildConfiguredPullBuilderHotkey(keyName)
    if !combo {
        return 0
    }

    SetConfiguredPullBuilderHotkey(combo["hotkey"], combo["display"])
    return 0
}

HandleConfiguredPullBuilderMouseMove(wParam, lParam, msg, hwnd) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    MouseGetPos(, , &winHwnd, &ctrlHwnd, 2)
    if winHwnd != ConfiguredPullBuilderState["guiHwnd"] {
        return
    }

    hoverDescriptions := ConfiguredPullBuilderState["hoverDescriptions"]
    if hoverDescriptions.Has(ctrlHwnd) {
        text := hoverDescriptions[ctrlHwnd]
    } else {
        text := ConfiguredPullBuilderState["defaultHoverText"]
    }

    ConfiguredPullBuilderState["helpText"].Text := text
}

HandleWindowManagerMouseWheel(wParam, lParam, msg, hwnd) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count
        || (!ConfiguredPullBuilderState["keyboardGuiHwnd"] && !ConfiguredPullBuilderState["openerGuiHwnd"]) {
        return
    }

    MouseGetPos(, , &winHwnd,, 2)
    delta := wParam >> 16
    if delta > 0x7FFF {
        delta -= 0x10000
    }

    if ConfiguredPullBuilderState["keyboardGuiHwnd"] && winHwnd = ConfiguredPullBuilderState["keyboardGuiHwnd"] {
        if delta > 0 {
            ChangeHotkeyViewerPage(-1)
        } else if delta < 0 {
            ChangeHotkeyViewerPage(1)
        }
        return 0
    }

    if ConfiguredPullBuilderState["openerGuiHwnd"] && winHwnd = ConfiguredPullBuilderState["openerGuiHwnd"] {
        if delta > 0 {
            ChangeWorkspaceOpenerPage(-1)
        } else if delta < 0 {
            ChangeWorkspaceOpenerPage(1)
        }
    }
    return 0
}

NormalizeBuilderKeyName(wParam, lParam) {
    vk := Format("vk{:02X}", wParam)
    sc := (lParam >> 16) & 0x1FF
    keyName := GetKeyName(vk . "sc" . Format("{:03X}", sc))
    if keyName = "" {
        keyName := GetKeyName(vk)
    }

    if keyName = "Esc" {
        return "Escape"
    }

    return keyName
}

IsBuilderModifierKey(keyName) {
    static modifierKeys := Map(
        "Shift", true,
        "LShift", true,
        "RShift", true,
        "Control", true,
        "Ctrl", true,
        "LControl", true,
        "RControl", true,
        "LCtrl", true,
        "RCtrl", true,
        "Alt", true,
        "Menu", true,
        "LMenu", true,
        "RMenu", true,
        "LAlt", true,
        "RAlt", true,
        "Win", true,
        "LWin", true,
        "RWin", true
    )

    return modifierKeys.Has(keyName)
}

BuildConfiguredPullBuilderHotkey(keyName) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return 0
    }

    modifierHotkey := ""
    modifierDisplay := ""
    hasModifier := false

    if ConfiguredPullBuilderState["winCheckbox"].Value = 1 {
        modifierHotkey .= "#"
        modifierDisplay .= (modifierDisplay = "" ? "Win" : "+Win")
        hasModifier := true
    }
    if ConfiguredPullBuilderState["ctrlCheckbox"].Value = 1 {
        modifierHotkey .= "^"
        modifierDisplay .= (modifierDisplay = "" ? "Ctrl" : "+Ctrl")
        hasModifier := true
    }
    if ConfiguredPullBuilderState["altCheckbox"].Value = 1 {
        modifierHotkey .= "!"
        modifierDisplay .= (modifierDisplay = "" ? "Alt" : "+Alt")
        hasModifier := true
    }
    if ConfiguredPullBuilderState["shiftCheckbox"].Value = 1 {
        modifierHotkey .= "+"
        modifierDisplay .= (modifierDisplay = "" ? "Shift" : "+Shift")
        hasModifier := true
    }

    hotkeyKey := ConvertKeyNameToHotkeyToken(keyName)
    if hotkeyKey = "" {
        return 0
    }

    if !hasModifier {
        modifierHotkey := "#"
        modifierDisplay := "Win"
    }

    return Map(
        "hotkey", modifierHotkey . hotkeyKey,
        "display", modifierDisplay . "+" . GetHotkeyDisplayName(keyName)
    )
}

ConvertKeyNameToHotkeyToken(keyName) {
    static specialKeys := Map(
        "Escape", "Esc",
        "Backspace", "Backspace",
        "Delete", "Delete",
        "Insert", "Insert",
        "Home", "Home",
        "End", "End",
        "PgUp", "PgUp",
        "PgDn", "PgDn",
        "Up", "Up",
        "Down", "Down",
        "Left", "Left",
        "Right", "Right",
        "Tab", "Tab",
        "Enter", "Enter",
        "Space", "Space",
        "AppsKey", "AppsKey",
        "PrintScreen", "PrintScreen",
        "CapsLock", "CapsLock",
        "ScrollLock", "ScrollLock",
        "Pause", "Pause",
        "NumLock", "NumLock"
    )

    if specialKeys.Has(keyName) {
        return specialKeys[keyName]
    }

    if RegExMatch(keyName, "i)^F([1-9]|1[0-9]|2[0-4])$") {
        return StrUpper(keyName)
    }

    if StrLen(keyName) = 1 {
        return StrLower(keyName)
    }

    if RegExMatch(keyName, "i)^Numpad([0-9])$") {
        return "Numpad" . SubStr(keyName, 7)
    }

    return keyName
}

GetHotkeyDisplayName(keyName) {
    static displayNames := Map(
        "PgUp", "PageUp",
        "PgDn", "PageDown",
        "AppsKey", "Menu"
    )

    if displayNames.Has(keyName) {
        return displayNames[keyName]
    }

    return keyName
}

LoadActiveWindowConfigIntoBuilder(windowInfo) {
    global ConfiguredPullHotkeys
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    sameAppIndex := FindConfiguredPullIndexByMatch(windowInfo["match"])
    if sameAppIndex {
        config := ConfiguredPullHotkeys[sameAppIndex]
        ApplyHotkeyToBuilderControls(config["hotkey"])
        if GetMainMonitorAction(config) = "focus-last" {
            SelectBuilderBehavior("main")
        } else {
            SelectBuilderBehavior("burner")
        }
        return
    }

    ConfiguredPullBuilderState["winCheckbox"].Value := 1
    ConfiguredPullBuilderState["ctrlCheckbox"].Value := 0
    ConfiguredPullBuilderState["altCheckbox"].Value := 0
    ConfiguredPullBuilderState["shiftCheckbox"].Value := 0
    SelectBuilderBehavior("main")
    SetConfiguredPullBuilderHotkey("", "None")
}

SetConfiguredPullBuilderHotkey(hotkey, display) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    ConfiguredPullBuilderState["selectedHotkey"] := hotkey
    ConfiguredPullBuilderState["selectedHotkeyDisplay"] := display
    ConfiguredPullBuilderState["selectedKeyText"].Text := display
    if hotkey != "" {
        ConfiguredPullBuilderState["applyButton"].Focus()
    }
    UpdateConfiguredPullBuilderConflictState()
}

ToggleBuilderCheckbox(key) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    checkbox := ConfiguredPullBuilderState[key]
    checkbox.Value := checkbox.Value = 1 ? 0 : 1
}

SelectBuilderBehavior(choice) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    if choice = "main" {
        ConfiguredPullBuilderState["mainRadio"].Value := 1
        ConfiguredPullBuilderState["burnerRadio"].Value := 0
        ConfiguredPullBuilderState["helpText"].Text := ConfiguredPullBuilderState["hoverDescriptions"][ConfiguredPullBuilderState["mainRadio"].Hwnd]
    } else {
        ConfiguredPullBuilderState["mainRadio"].Value := 0
        ConfiguredPullBuilderState["burnerRadio"].Value := 1
        ConfiguredPullBuilderState["helpText"].Text := ConfiguredPullBuilderState["hoverDescriptions"][ConfiguredPullBuilderState["burnerRadio"].Hwnd]
    }
}

StartGuiDrag(gui, *) {
    PostMessage(0xA1, 2, , , "ahk_id " gui.Hwnd)
}

ReflowConfiguredPullBuilderLayout(showConflict) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    conflictText := ConfiguredPullBuilderState["conflictText"]
    helpText := ConfiguredPullBuilderState["helpText"]
    applyButton := ConfiguredPullBuilderState["applyButton"]
    cancelButton := ConfiguredPullBuilderState["cancelButton"]
    hotkeysButton := ConfiguredPullBuilderState["hotkeysButton"]

    if showConflict {
        conflictText.Move(, 278, , 20)
        helpText.Move(, 430)
        applyButton.Move(, 488)
        cancelButton.Move(, 488)
        hotkeysButton.Move(, 488)
    } else {
        conflictText.Move(, 278, , 0)
        helpText.Move(, 414)
        applyButton.Move(, 472)
        cancelButton.Move(, 472)
        hotkeysButton.Move(, 472)
    }

    conflictText.Visible := showConflict
}

UpdateConfiguredPullBuilderConflictState() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    uiTheme := ConfiguredPullBuilderState["uiTheme"]
    selectedHotkey := ConfiguredPullBuilderState["selectedHotkey"]
    conflictText := ConfiguredPullBuilderState["conflictText"]
    selectedKeyBox := ConfiguredPullBuilderState["selectedKeyBox"]
    windowInfo := ConfiguredPullBuilderState["windowInfo"]

    if selectedHotkey = "" {
        selectedKeyBox.Opt("Background" . uiTheme["input"])
        ReflowConfiguredPullBuilderLayout(false)
        return
    }

    conflict := FindConfiguredPullBuilderConflict(
        selectedHotkey,
        ConfiguredPullBuilderState["editingKind"],
        ConfiguredPullBuilderState["editingKind"] = "app" ? windowInfo["match"] : "",
        ConfiguredPullBuilderState["editingKind"] = "shared" ? ConfiguredPullBuilderState["editingSharedId"] : ""
    )
    if conflict {
        conflictText.Text := conflict["message"]
        selectedKeyBox.Opt("Background" . uiTheme["dangerFill"])
        ReflowConfiguredPullBuilderLayout(true)
        return
    }

    selectedKeyBox.Opt("Background" . uiTheme["input"])
    ReflowConfiguredPullBuilderLayout(false)
}

SetConfiguredPullBuilderEditingMode(kind, windowInfo, sharedId := "") {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    ConfiguredPullBuilderState["editingKind"] := kind
    ConfiguredPullBuilderState["editingSharedId"] := sharedId
    ConfiguredPullBuilderState["windowInfo"] := windowInfo
    ConfiguredPullBuilderState["appLabelText"].Text := windowInfo["label"]
    ConfiguredPullBuilderState["appMatchText"].Text := windowInfo["match"]

    if kind = "shared" {
        ConfiguredPullBuilderState["mainRadio"].Enabled := false
        ConfiguredPullBuilderState["burnerRadio"].Enabled := false
        ConfiguredPullBuilderState["helpText"].Text := "Shared hotkeys control built-in script actions. The behavior options do not apply here."
    } else {
        ConfiguredPullBuilderState["mainRadio"].Enabled := true
        ConfiguredPullBuilderState["burnerRadio"].Enabled := true
        ConfiguredPullBuilderState["helpText"].Text := ConfiguredPullBuilderState["defaultHoverText"]
    }
}

FindConfiguredPullBuilderConflict(hotkey, editingKind := "app", currentMatch := "", currentSharedId := "") {
    global SharedHotkeyRegistry

    registryEntry := FindSharedRegistryEntryByHotkey(hotkey)
    if registryEntry && !(editingKind = "shared" && registryEntry["id"] = currentSharedId) {
        return Map(
            "type", "shared",
            "message", "Conflicting with this hotkey: " . registryEntry["action"],
            "label", registryEntry["action"],
            "id", registryEntry["id"]
        )
    }

    sameAppIndex := FindConfiguredPullIndexByMatch(currentMatch)
    collisionIndex := FindConfiguredPullIndexByHotkey(hotkey)
    if collisionIndex && collisionIndex != sameAppIndex {
        collisionLabel := GetConfiguredAppLabel(ConfiguredPullHotkeys[collisionIndex])
        return Map(
            "type", "app",
            "message", "Conflicting with this hotkey: " . collisionLabel,
            "label", collisionLabel,
            "index", collisionIndex
        )
    }

    return 0
}

FindSharedRegistryEntryByHotkey(hotkey) {
    global SharedHotkeyRegistry

    for _, entry in SharedHotkeyRegistry {
        if entry["hotkey"] = hotkey {
            return entry
        }
    }

    return 0
}

FindSharedRegistryEntryById(id) {
    global SharedHotkeyRegistry

    for _, entry in SharedHotkeyRegistry {
        if entry.Has("id") && entry["id"] = id {
            return entry
        }
    }

    return 0
}

FindSharedRegistryIndexById(id) {
    global SharedHotkeyRegistry

    for index, entry in SharedHotkeyRegistry {
        if entry.Has("id") && entry["id"] = id {
            return index
        }
    }

    return 0
}

ToggleHotkeyKeyboardViewer() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    if ConfiguredPullBuilderState["keyboardGui"] {
        CloseHotkeyKeyboardViewer()
        return
    }

    OpenHotkeyKeyboardViewer()
}

OpenHotkeyKeyboardViewer(initialPage := 1, showOptions := "w720 h620") {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }
    uiTheme := GetUiTheme()

    keyboardGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Current Hotkeys")
    keyboardGui.SetFont("s9", "Segoe UI")
    keyboardGui.BackColor := uiTheme["surface"]
    keyboardGui.MarginX := 0
    keyboardGui.MarginY := 0
    keyboardGui.OnEvent("Close", (*) => CloseHotkeyKeyboardViewer())
    keyboardGui.OnEvent("Escape", (*) => CloseHotkeyKeyboardViewer())

    headerBar := keyboardGui.AddText("x0 y0 w676 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(keyboardGui))
    keyboardGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := keyboardGui.AddText("x14 y9 w600 c" . uiTheme["headerText"], "Current Hotkeys")
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(keyboardGui))
    closeButton := keyboardGui.AddText("x682 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")
    closeButton.OnEvent("Click", (*) => CloseHotkeyKeyboardViewer())

    keyboardGui.SetFont("s9", "Segoe UI")
    keyboardGui.AddText("x18 y58 w676 h34 c" . uiTheme["muted"], "Click a card to select it. Double-click or use Open to edit. Shared script hotkeys are gray, app hotkeys are green.")
    openButton := keyboardGui.AddButton("x18 y98 w86 h30", "Open")
    actionButton := keyboardGui.AddButton("x114 y98 w86 h30", "Delete")
    selectionText := keyboardGui.AddText("x214 y104 w488 h20 c" . uiTheme["muted"], "Select a hotkey card.")
    openButton.OnEvent("Click", (*) => OpenSelectedHotkeyViewerEntry())
    actionButton.OnEvent("Click", (*) => PerformSelectedHotkeyViewerAction())

    prevButton := keyboardGui.AddButton("x438 y576 w92 h28", "Previous")
    pageLabel := keyboardGui.AddText("x540 y581 w90 Center c" . uiTheme["muted"], "Page 1 of 1")
    nextButton := keyboardGui.AddButton("x636 y576 w66 h28", "Next")
    prevButton.OnEvent("Click", (*) => ChangeHotkeyViewerPage(-1))
    nextButton.OnEvent("Click", (*) => ChangeHotkeyViewerPage(1))

    ConfiguredPullBuilderState["keyboardGui"] := keyboardGui
    ConfiguredPullBuilderState["keyboardGuiHwnd"] := keyboardGui.Hwnd
    ConfiguredPullBuilderState["keyboardCloseButton"] := closeButton
    ConfiguredPullBuilderState["keyboardPrevButton"] := prevButton
    ConfiguredPullBuilderState["keyboardNextButton"] := nextButton
    ConfiguredPullBuilderState["keyboardPageLabel"] := pageLabel
    ConfiguredPullBuilderState["keyboardOpenButton"] := openButton
    ConfiguredPullBuilderState["keyboardActionButton"] := actionButton
    ConfiguredPullBuilderState["keyboardSelectionText"] := selectionText
    ConfiguredPullBuilderState["keyboardPageIndex"] := initialPage
    ConfiguredPullBuilderState["keyboardPages"] := []
    ConfiguredPullBuilderState["keyboardRenderedControls"] := []
    if !ConfiguredPullBuilderState.Has("keyboardSelectedKind") {
        ConfiguredPullBuilderState["keyboardSelectedKind"] := ""
    }
    if !ConfiguredPullBuilderState.Has("keyboardSelectedId") {
        ConfiguredPullBuilderState["keyboardSelectedId"] := ""
    }
    ConfiguredPullBuilderState["keyboardCardControls"] := []

    RenderHotkeyCards(keyboardGui, uiTheme)

    keyboardGui.Show(showOptions)
}

CloseHotkeyKeyboardViewer() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    if ConfiguredPullBuilderState.Has("keyboardGui") && ConfiguredPullBuilderState["keyboardGui"] {
        try ConfiguredPullBuilderState["keyboardGui"].Destroy()
        ConfiguredPullBuilderState["keyboardGui"] := 0
        ConfiguredPullBuilderState["keyboardGuiHwnd"] := 0
        ConfiguredPullBuilderState["keyboardCloseButton"] := 0
        ConfiguredPullBuilderState["keyboardPrevButton"] := 0
        ConfiguredPullBuilderState["keyboardNextButton"] := 0
        ConfiguredPullBuilderState["keyboardPageLabel"] := 0
        ConfiguredPullBuilderState["keyboardOpenButton"] := 0
        ConfiguredPullBuilderState["keyboardActionButton"] := 0
        ConfiguredPullBuilderState["keyboardSelectionText"] := 0
        ConfiguredPullBuilderState["keyboardPageIndex"] := 1
        ConfiguredPullBuilderState["keyboardPages"] := []
        ConfiguredPullBuilderState["keyboardRenderedControls"] := []
        ConfiguredPullBuilderState["keyboardCardControls"] := []
    }
}

OpenWorkspaceOpenerBrowser(initialPage := 1, showOptions := "w760 h640") {
    global ConfiguredPullBuilderState

    EnsureWorkspaceOpenerState()

    CloseWorkspaceOpenerBrowser()
    uiTheme := GetUiTheme()
    ConfiguredPullBuilderState["uiTheme"] := uiTheme
    openerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Workspace Openers")
    openerGui.SetFont("s9", "Segoe UI")
    openerGui.BackColor := uiTheme["surface"]
    openerGui.MarginX := 0
    openerGui.MarginY := 0
    openerGui.OnEvent("Close", (*) => CloseWorkspaceOpenerBrowser())
    openerGui.OnEvent("Escape", (*) => CloseWorkspaceOpenerBrowser())

    headerBar := openerGui.AddText("x0 y0 w716 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(openerGui))
    openerGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := openerGui.AddText("x14 y9 w620 c" . uiTheme["headerText"], "Workspace Openers")
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(openerGui))
    closeButton := openerGui.AddText("x722 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")
    closeButton.OnEvent("Click", (*) => CloseWorkspaceOpenerBrowser())

    openerGui.SetFont("s9", "Segoe UI")
    openerGui.AddText("x18 y58 w700 h34 c" . uiTheme["muted"], "Capture your current desktop layout, then relaunch those apps and window positions later.")

    captureButton := openerGui.AddButton("x18 y104 w198 h30", "Capture Current Workspace")
    launchButton := openerGui.AddButton("x230 y104 w92 h30", "Launch")
    renameButton := openerGui.AddButton("x336 y104 w92 h30", "Rename")
    deleteButton := openerGui.AddButton("x442 y104 w92 h30", "Delete")

    captureButton.OnEvent("Click", (*) => CaptureCurrentWorkspaceProfile())
    launchButton.OnEvent("Click", (*) => LaunchSelectedWorkspaceOpener())
    renameButton.OnEvent("Click", (*) => RenameSelectedWorkspaceOpener())
    deleteButton.OnEvent("Click", (*) => DeleteSelectedWorkspaceOpener())

    detailsText := openerGui.AddText("x18 y532 w700 h62 c" . uiTheme["muted"], "Select a saved workspace to preview what it will open.")
    prevButton := openerGui.AddButton("x478 y602 w92 h28", "Previous")
    pageLabel := openerGui.AddText("x580 y607 w90 Center c" . uiTheme["muted"], "Page 1 of 1")
    nextButton := openerGui.AddButton("x676 y602 w66 h28", "Next")
    prevButton.OnEvent("Click", (*) => ChangeWorkspaceOpenerPage(-1))
    nextButton.OnEvent("Click", (*) => ChangeWorkspaceOpenerPage(1))

    ConfiguredPullBuilderState["openerGui"] := openerGui
    ConfiguredPullBuilderState["openerGuiHwnd"] := openerGui.Hwnd
    ConfiguredPullBuilderState["openerShowOptions"] := showOptions
    ConfiguredPullBuilderState["openerCloseButton"] := closeButton
    ConfiguredPullBuilderState["openerPageIndex"] := initialPage
    ConfiguredPullBuilderState["openerPageLabel"] := pageLabel
    ConfiguredPullBuilderState["openerPrevButton"] := prevButton
    ConfiguredPullBuilderState["openerNextButton"] := nextButton
    ConfiguredPullBuilderState["openerDetailsText"] := detailsText
    ConfiguredPullBuilderState["openerCaptureButton"] := captureButton
    ConfiguredPullBuilderState["openerLaunchButton"] := launchButton
    ConfiguredPullBuilderState["openerRenameButton"] := renameButton
    ConfiguredPullBuilderState["openerDeleteButton"] := deleteButton

    ConfiguredPullBuilderState["openerShowOptions"] := "w760 h640"
    openerGui.Show("Hide " . showOptions)
    RenderWorkspaceOpenerBrowser()
    openerGui.Show(showOptions)
}

CloseWorkspaceOpenerBrowser() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    if ConfiguredPullBuilderState.Has("openerGui") && ConfiguredPullBuilderState["openerGui"] {
        try ConfiguredPullBuilderState["openerGui"].Destroy()
        ConfiguredPullBuilderState["openerGui"] := 0
        ConfiguredPullBuilderState["openerGuiHwnd"] := 0
        ConfiguredPullBuilderState["openerShowOptions"] := ""
        ConfiguredPullBuilderState["openerPageLabel"] := 0
        ConfiguredPullBuilderState["openerPrevButton"] := 0
        ConfiguredPullBuilderState["openerNextButton"] := 0
        ConfiguredPullBuilderState["openerDetailsText"] := 0
        ConfiguredPullBuilderState["openerCloseButton"] := 0
        ConfiguredPullBuilderState["openerCaptureButton"] := 0
        ConfiguredPullBuilderState["openerLaunchButton"] := 0
        ConfiguredPullBuilderState["openerRenameButton"] := 0
        ConfiguredPullBuilderState["openerDeleteButton"] := 0
        ConfiguredPullBuilderState["openerDynamicControls"] := []
        ConfiguredPullBuilderState["openerCardControls"] := []
    }
}

RenderWorkspaceOpenerBrowser() {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["openerGui"] {
        return
    }

    openerGui := ConfiguredPullBuilderState["openerGui"]
    openerGui.SetFont("s10", "Segoe UI Semibold")
    cardsPerPage := 6
    start := ((ConfiguredPullBuilderState["openerPageIndex"] - 1) * cardsPerPage) + 1
    pageProfiles := []
    index := start
    while index <= WorkspaceOpenerProfiles.Length && pageProfiles.Length < cardsPerPage {
        pageProfiles.Push(WorkspaceOpenerProfiles[index])
        index += 1
    }

    ; clear old dynamic controls by recreating the window page in place
    if ConfiguredPullBuilderState.Has("openerDynamicControls") {
        for _, ctrl in ConfiguredPullBuilderState["openerDynamicControls"] {
            try ctrl.Destroy()
        }
    }
    dynamicControls := []
    cardControls := []
    cardWidth := 208
    cardHeight := 104
    startX := 18
    startY := 152
    colGap := 16
    rowGap := 16
    cols := 3
    uiTheme := ConfiguredPullBuilderState["uiTheme"]
    viewportClear := openerGui.AddText("x18 y152 w700 h348 Background" . uiTheme["surface"], "")
    dynamicControls.Push(viewportClear)

    for profileIndex, profile in pageProfiles {
        col := Mod(profileIndex - 1, cols)
        row := Floor((profileIndex - 1) / cols)
        x := startX + (col * (cardWidth + colGap))
        y := startY + (row * (cardHeight + rowGap))
        buttonText := GetWorkspaceOpenerCardText(profile)
        cardButton := openerGui.AddButton(Format("x{} y{} w{} h{} +0x2000", x, y, cardWidth, cardHeight), buttonText)
        cardButton.OnEvent("Click", HandleWorkspaceOpenerCardClick.Bind(profile["id"]))
        dynamicControls.Push(cardButton)
        cardControls.Push(Map(
            "profileId", profile["id"],
            "button", cardButton
        ))
    }

    if pageProfiles.Length = 0 {
        emptyText := openerGui.AddText("x18 y202 w700 h60 Center c" . uiTheme["muted"], "No saved workspaces yet. Capture your current desktop to create one.")
        dynamicControls.Push(emptyText)
    }

    ConfiguredPullBuilderState["openerDynamicControls"] := dynamicControls
    ConfiguredPullBuilderState["openerCardControls"] := cardControls
    UpdateWorkspaceOpenerPagination()
    UpdateWorkspaceOpenerSelectionVisuals()
    UpdateWorkspaceOpenerDetails()
}

GetWorkspaceOpenerSummary(profile) {
    items := profile["items"]
    if items.Length = 0 {
        return "Empty workspace"
    }

    summary := ""
    shown := 0
    for _, item in items {
        label := TrimWorkspaceOpenerLabel(GetSanitizedWorkspaceOpenerLabel(item), 26)
        summary .= (summary = "" ? "" : "`n") . label
        shown += 1
        if shown = 3 {
            break
        }
    }

    if items.Length > shown {
        summary .= "`n+" . (items.Length - shown) . " more"
    }

    return summary
}

GetWorkspaceOpenerCardText(profile) {
    title := TrimWorkspaceOpenerLabel(profile["name"], 20)
    subtitle := GetWorkspaceOpenerCardSubtitle(profile)
    return title . "`n`n" . subtitle
}

GetWorkspaceOpenerCardSubtitle(profile) {
    items := profile["items"]
    if items.Length = 0 {
        return "No apps saved"
    }

    preview := []
    shown := 0
    for _, item in items {
        preview.Push(TrimWorkspaceOpenerLabel(GetSanitizedWorkspaceOpenerLabel(item), 14))
        shown += 1
        if shown = 2 {
            break
        }
    }

    subtitle := JoinTextParts(preview, ", ")
    if items.Length > shown {
        subtitle .= " +" . (items.Length - shown)
    }

    return subtitle
}

JoinTextParts(parts, separator := ", ") {
    text := ""
    for _, part in parts {
        text .= (text = "" ? "" : separator) . part
    }
    return text
}

GetSanitizedWorkspaceOpenerLabel(item) {
    label := item.Has("label") && item["label"] != "" ? item["label"] : item["processName"]
    processName := item.Has("processName") ? item["processName"] : label
    processLabel := RegExReplace(processName, "\.exe$", "")

    replacements := Map(
        "WindowsTerminal", "Windows Terminal",
        "Code", "VS Code"
    )
    if replacements.Has(processLabel) {
        processLabel := replacements[processLabel]
    }

    if item.Has("path") && item["path"] != "" {
        SplitPath(item["path"], &exeName)
        if exeName != "" {
            pathLabel := RegExReplace(exeName, "\.exe$", "")
            if replacements.Has(pathLabel) {
                pathLabel := replacements[pathLabel]
            }
            processLabel := pathLabel
        }
    }

    return processLabel
}

GetWorkspaceOpenerMeta(profile) {
    items := profile["items"]
    if items.Length = 0 {
        return "No apps saved"
    }

    monitors := Map()
    for _, item in items {
        monitors[item["monitorIndex"]] := true
    }

    monitorCount := monitors.Count
    return items.Length . " app" . (items.Length = 1 ? "" : "s") . " across " . monitorCount . " monitor" . (monitorCount = 1 ? "" : "s")
}

GetWindowsTerminalShellSpec(hwnd) {
    try terminalPid := WinGetPID("ahk_id " hwnd)
    catch
        return 0

    processes := GetProcessSnapshot()
    if !processes.Has(terminalPid) {
        return 0
    }

    descendants := GetDescendantProcesses(processes, terminalPid)
    if descendants.Length = 0 {
        return 0
    }

    best := 0
    bestScore := -1
    for _, proc in descendants {
        score := GetTerminalShellScore(proc["name"], proc["commandLine"])
        if score > bestScore {
            best := proc
            bestScore := score
        }
    }

    if !best || bestScore < 0 {
        return 0
    }

    command := Trim(best["commandLine"])
    if command = "" {
        command := best["name"]
    }

    return Map(
        "shell", best["name"],
        "command", command
    )
}

InferWindowsTerminalShellSpec(title) {
    title := Trim(title)
    if title = "" {
        return 0
    }

    lowerTitle := StrLower(title)
    if lowerTitle = "windows powershell" || lowerTitle = "administrator: windows powershell" {
        return Map("shell", "powershell.exe", "command", "powershell.exe", "shellKind", "powershell")
    }
    if lowerTitle = "powershell" || lowerTitle = "powershell 7" || lowerTitle = "pwsh" {
        return Map("shell", "pwsh.exe", "command", "pwsh.exe", "shellKind", "pwsh")
    }
    if lowerTitle = "command prompt" || lowerTitle = "cmd" || lowerTitle = "cmd.exe" {
        return Map("shell", "cmd.exe", "command", "cmd.exe", "shellKind", "cmd")
    }
    if RegExMatch(lowerTitle, "^[^@]+@[^:]+:.*$") {
        promptIdentity := title
        return Map("shell", "wsl.exe", "command", "wsl.exe", "shellKind", "wsl", "promptIdentity", promptIdentity)
    }
    if RegExMatch(lowerTitle, "^(ubuntu|debian|kali|arch|opensuse|fedora|alpine)([\s-].*)?$") {
        distro := GetWslDistroNameFromTitle(title)
        command := distro != "" ? 'wsl.exe -d "' . distro . '"' : "wsl.exe"
        return Map("shell", "wsl.exe", "command", command, "shellKind", "wsl", "distro", distro, "profileName", title)
    }

    return 0
}

GetTerminalShellKind(shellName) {
    shellName := StrLower(Trim(shellName))
    if shellName = "wsl.exe" || RegExMatch(shellName, "^ubuntu(\d+(\.\d+)*)?\.exe$") || RegExMatch(shellName, "^(debian|kali|arch|opensuse|fedora|alpine)\.exe$") {
        return "wsl"
    }
    if shellName = "powershell.exe" {
        return "powershell"
    }
    if shellName = "pwsh.exe" {
        return "pwsh"
    }
    if shellName = "cmd.exe" {
        return "cmd"
    }
    return shellName
}

GetWslDistroNameFromTitle(title) {
    title := Trim(title)
    if title = "" {
        return ""
    }

    if RegExMatch(title, "i)^(Ubuntu)(?:[\s-].*)?$", &match) {
        return match[1]
    }
    if RegExMatch(title, "i)^(Debian|Kali|Arch|openSUSE|Fedora|Alpine)(?:[\s-].*)?$", &match) {
        return match[1]
    }

    return ""
}

ResolveWslDistroFromPrompt(title) {
    identity := GetWslPromptIdentity(title)
    if !identity {
        return ""
    }

    target := StrLower(identity["user"] . "@" . identity["host"])
    distros := GetInstalledWslDistros()
    for _, distro in distros {
        currentIdentity := GetWslIdentityForDistro(distro)
        if currentIdentity = "" {
            continue
        }
        if StrLower(currentIdentity) = target {
            return distro
        }
    }

    return ""
}

GetWslPromptIdentity(title) {
    title := Trim(title)
    if !RegExMatch(title, "^([^@]+)@([^:]+):", &match) {
        return 0
    }

    return Map(
        "user", Trim(match[1]),
        "host", Trim(match[2])
    )
}

GetInstalledWslDistros(forceRefresh := false) {
    static cachedDistros := []

    if !forceRefresh && cachedDistros.Length {
        return cachedDistros
    }

    cachedDistros := []
    output := ReadCommandOutput("wsl.exe -l -q", 10000)
    if output = "" {
        return cachedDistros
    }

    output := StrReplace(output, Chr(0), "")
    lines := StrSplit(output, "`n", "`r")
    for _, line in lines {
        distro := Trim(line)
        if distro != "" {
            cachedDistros.Push(distro)
        }
    }

    return cachedDistros
}

GetWslIdentityForDistro(distro) {
    static cachedIdentities := Map()

    if cachedIdentities.Has(distro) {
        return cachedIdentities[distro]
    }

    command := 'wsl.exe -d "' . distro . '" sh -lc "printf \"%s@%s\" \"$USER\" \"$(hostname)\""'
    identity := Trim(ReadCommandOutput(command, 20000))
    identity := StrReplace(identity, Chr(0), "")
    cachedIdentities[distro] := identity
    return identity
}

ReadCommandOutput(command, timeoutMs := 10000) {
    try exec := ComObject("WScript.Shell").Exec(command)
    catch
        return ""

    startTick := A_TickCount
    while !exec.Status {
        if (A_TickCount - startTick) >= timeoutMs {
            try exec.Terminate()
            break
        }
        Sleep(50)
    }

    output := ""
    try output := exec.StdOut.ReadAll()
    catch
        output := ""

    if output = "" {
        try output := exec.StdErr.ReadAll()
        catch
            output := ""
    }

    return output
}

GetProcessSnapshot() {
    processes := Map()
    try service := ComObject("WbemScripting.SWbemLocator").ConnectServer(".", "root\cimv2")
    catch
        return processes

    for proc in service.ExecQuery("SELECT ProcessId, ParentProcessId, Name, CommandLine FROM Win32_Process") {
        processes[proc.ProcessId + 0] := Map(
            "pid", proc.ProcessId + 0,
            "parentPid", proc.ParentProcessId + 0,
            "name", proc.Name != "" ? proc.Name : "",
            "commandLine", proc.CommandLine != "" ? proc.CommandLine : ""
        )
    }

    return processes
}

GetDescendantProcesses(processes, rootPid) {
    descendants := []
    queue := [rootPid]

    while queue.Length {
        parentPid := queue.RemoveAt(1)
        for _, proc in processes {
            if proc["parentPid"] != parentPid {
                continue
            }

            descendants.Push(proc)
            queue.Push(proc["pid"])
        }
    }

    return descendants
}

GetTerminalShellScore(processName, commandLine := "") {
    name := StrLower(processName)
    command := StrLower(commandLine)

    if name = "wsl.exe" {
        return 100
    }
    if RegExMatch(name, "^ubuntu(\d+(\.\d+)*)?\.exe$") {
        return 95
    }
    if RegExMatch(name, "^(debian|kali|arch|opensuse|fedora|alpine)\.exe$") {
        return 90
    }
    if name = "pwsh.exe" {
        return 80
    }
    if name = "powershell.exe" {
        return 70
    }
    if name = "cmd.exe" {
        return 60
    }
    if name = "bash.exe" {
        return 50
    }
    if InStr(command, "wsl.exe") {
        return 45
    }

    return -1
}

TrimWorkspaceOpenerLabel(text, maxLen := 24) {
    if StrLen(text) <= maxLen {
        return text
    }

    return SubStr(text, 1, maxLen - 3) . "..."
}

UpdateWorkspaceOpenerPagination() {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["openerPageLabel"] {
        return
    }

    cardsPerPage := 6
    pageCount := Max(Ceil(WorkspaceOpenerProfiles.Length / cardsPerPage), 1)
    pageIndex := Max(Min(ConfiguredPullBuilderState["openerPageIndex"], pageCount), 1)
    ConfiguredPullBuilderState["openerPageIndex"] := pageIndex
    ConfiguredPullBuilderState["openerPageLabel"].Text := "Page " . pageIndex . " of " . pageCount
    ConfiguredPullBuilderState["openerPrevButton"].Enabled := pageIndex > 1
    ConfiguredPullBuilderState["openerNextButton"].Enabled := pageIndex < pageCount
}

RefreshWorkspaceOpenerBrowser(pageIndex := 0) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["openerGui"] {
        return
    }

    openerGui := ConfiguredPullBuilderState["openerGui"]
    WinGetPos(&guiX, &guiY,,, "ahk_id " openerGui.Hwnd)
    showOptions := ConfiguredPullBuilderState.Has("openerShowOptions") && ConfiguredPullBuilderState["openerShowOptions"] != ""
        ? ConfiguredPullBuilderState["openerShowOptions"]
        : "w760 h640"
    if pageIndex = 0 {
        pageIndex := ConfiguredPullBuilderState["openerPageIndex"]
    }

    CloseWorkspaceOpenerBrowser()
    OpenWorkspaceOpenerBrowser(pageIndex, Format("x{} y{} {}", guiX, guiY, showOptions))
}

ChangeWorkspaceOpenerPage(step) {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    if !ConfiguredPullBuilderState.Count {
        return
    }

    cardsPerPage := 6
    pageCount := Max(Ceil(WorkspaceOpenerProfiles.Length / cardsPerPage), 1)
    newPage := ConfiguredPullBuilderState["openerPageIndex"] + step
    if newPage < 1 || newPage > pageCount {
        return
    }

    ConfiguredPullBuilderState["openerPageIndex"] := newPage
    RefreshWorkspaceOpenerBrowser(newPage)
}

HandleWorkspaceOpenerCardClick(profileId, *) {
    global ConfiguredPullBuilderState

    static lastProfileId := ""
    static lastClickTick := 0

    if !ConfiguredPullBuilderState.Count {
        return
    }

    currentTick := A_TickCount
    isDoubleClick := (lastProfileId = profileId) && (currentTick - lastClickTick <= 325)
    lastProfileId := profileId
    lastClickTick := currentTick

    SelectWorkspaceOpenerProfile(profileId)
    if isDoubleClick {
        LaunchWorkspaceOpenerById(profileId)
    }
}

SelectWorkspaceOpenerProfile(profileId, *) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    ConfiguredPullBuilderState["openerSelectedId"] := profileId
    UpdateWorkspaceOpenerSelectionVisuals()
    UpdateWorkspaceOpenerDetails()
}

UpdateWorkspaceOpenerSelectionVisuals() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState.Has("openerCardControls") {
        return
    }

    uiTheme := ConfiguredPullBuilderState["uiTheme"]
    selectedId := ConfiguredPullBuilderState["openerSelectedId"]
    focusedButton := 0
    for _, card in ConfiguredPullBuilderState["openerCardControls"] {
        if card["profileId"] = selectedId {
            focusedButton := card["button"]
            break
        }
    }

    if focusedButton {
        try focusedButton.Focus()
    }
}

UpdateWorkspaceOpenerDetails() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["openerDetailsText"] {
        return
    }

    profile := FindWorkspaceOpenerProfileById(ConfiguredPullBuilderState["openerSelectedId"])
    if !profile {
        ConfiguredPullBuilderState["openerDetailsText"].Text := "Select a saved workspace to preview what it will open."
        return
    }

    details := profile["name"] . "`n"
    for _, item in profile["items"] {
        label := GetSanitizedWorkspaceOpenerLabel(item)
        details .= label . " -> monitor " . item["monitorIndex"] . " (" . GetWorkspaceOpenerPlacementLabel(item) . ")" . "`n"
    }
    ConfiguredPullBuilderState["openerDetailsText"].Text := RTrim(details, "`n")
}

FindWorkspaceOpenerProfileById(profileId) {
    global WorkspaceOpenerProfiles

    for _, profile in WorkspaceOpenerProfiles {
        if profile["id"] = profileId {
            return profile
        }
    }

    return 0
}

CaptureCurrentWorkspaceProfile() {
    global WorkspaceOpenerProfiles
    global ConfiguredPullBuilderState

    defaultName := "Workspace " . (WorkspaceOpenerProfiles.Length + 1)
    result := ShowThemedTextInputDialog("Capture Workspace", "Name this captured workspace:", defaultName)
    if result["result"] != "OK" {
        return
    }

    items := CaptureCurrentWorkspaceItems()
    if items.Length = 0 {
        ShowThemedMessageDialog("Capture Workspace", "No normal application windows were found to capture.")
        return
    }

    profileId := "workspace-" . A_Now . "-" . Random(100, 999)
    WorkspaceOpenerProfiles.Push(Map(
        "id", profileId,
        "name", Trim(result["value"]) != "" ? Trim(result["value"]) : defaultName,
        "items", items
    ))
    SaveWorkspaceOpenerProfiles(WorkspaceOpenerProfiles)
    ConfiguredPullBuilderState["openerSelectedId"] := profileId
    ConfiguredPullBuilderState["openerPageIndex"] := Max(Ceil(WorkspaceOpenerProfiles.Length / 6), 1)
    RefreshWorkspaceOpenerBrowser(ConfiguredPullBuilderState["openerPageIndex"])
}

CaptureCurrentWorkspaceItems() {
    items := []
    hwnds := WinGetList()
    for _, hwnd in hwnds {
        item := CaptureWorkspaceWindowItem(hwnd)
        if item {
            items.Push(item)
        }
    }
    return items
}

CaptureWorkspaceWindowItem(hwnd) {
    static ignoredTitles := Map("Hotkey Editor", true, "Current Hotkeys", true, "Workspace Openers", true)

    if !DllCall("IsWindowVisible", "ptr", hwnd, "int") {
        return 0
    }

    try title := WinGetTitle("ahk_id " hwnd)
    catch
        return 0

    if title = "" || ignoredTitles.Has(title) {
        return 0
    }

    try processName := WinGetProcessName("ahk_id " hwnd)
    catch
        return 0

    if !IsCapturableWorkspaceWindow(hwnd, processName, title) {
        return 0
    }

    placement := GetWindowPlacementInfo(hwnd)
    if !placement || placement["w"] < 120 || placement["h"] < 80 {
        return 0
    }

    path := ""
    try path := WinGetProcessPath("ahk_id " hwnd)
    item := Map(
        "processName", processName,
        "path", path,
        "title", title,
        "label", GetSanitizedProcessLabel(processName, path),
        "x", placement["x"],
        "y", placement["y"],
        "w", placement["w"],
        "h", placement["h"],
        "state", placement["state"],
        "monitorIndex", placement["monitorIndex"]
    )

    if StrLower(processName) = "windowsterminal.exe" {
        shellSpec := GetWindowsTerminalShellSpec(hwnd)
        if !shellSpec {
            shellSpec := InferWindowsTerminalShellSpec(title)
        }
        item["launchKind"] := "windows-terminal"
        if shellSpec {
            item["shellKind"] := shellSpec.Has("shellKind") ? shellSpec["shellKind"] : GetTerminalShellKind(shellSpec["shell"])
            if shellSpec.Has("distro") && shellSpec["distro"] != "" {
                item["wslDistro"] := shellSpec["distro"]
            }
            if shellSpec.Has("profileName") && shellSpec["profileName"] != "" {
                item["profileName"] := shellSpec["profileName"]
            }
            if shellSpec.Has("promptIdentity") && shellSpec["promptIdentity"] != "" {
                item["promptIdentity"] := shellSpec["promptIdentity"]
            } else if RegExMatch(title, "^[^@]+@[^:]+:.*$") {
                item["promptIdentity"] := title
            }
        }
        item["label"] := GetWorkspaceOpenerTerminalLabel(item)
    } else if path != "" && IsPackagedAppPath(path) {
        item["launchKind"] := "packaged-app"
    } else if path != "" {
        item["launchKind"] := "app-path"
    }

    return item
}

IsCapturableWorkspaceWindow(hwnd, processName, title) {
    if InStr(processName, "AutoHotkey") {
        return false
    }

    if IsWindowCloaked(hwnd) {
        return false
    }

    try className := WinGetClass("ahk_id " hwnd)
    catch
        return false

    static ignoredClasses := Map(
        "Shell_TrayWnd", true,
        "NotifyIconOverflowWindow", true,
        "Progman", true,
        "WorkerW", true
    )
    if ignoredClasses.Has(className) {
        return false
    }

    exStyle := 0
    try exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & 0x80) { ; WS_EX_TOOLWINDOW
        return false
    }

    state := 0
    try state := WinGetMinMax("ahk_id " hwnd)
    if state = -1 {
        return false
    }

    if StrLower(processName) = "explorer.exe" {
        return className = "CabinetWClass" || className = "ExploreWClass"
    }

    return title != ""
}

IsWindowCloaked(hwnd) {
    cloaked := Buffer(4, 0)
    result := DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "ptr", cloaked, "uint", 4, "int")
    if result != 0 {
        return false
    }

    return NumGet(cloaked, 0, "uint") != 0
}

GetSanitizedProcessLabel(processName, path := "") {
    label := RegExReplace(processName, "\.exe$", "")
    replacements := Map(
        "WindowsTerminal", "Windows Terminal",
        "Code", "VS Code"
    )

    if path != "" {
        SplitPath(path, &exeName)
        if exeName != "" {
            label := RegExReplace(exeName, "\.exe$", "")
        }
    }

    if replacements.Has(label) {
        return replacements[label]
    }

    return label
}

GetWorkspaceOpenerTerminalLabel(item) {
    if item.Has("shellKind") && StrLower(item["shellKind"]) = "wsl" {
        return "WSL"
    }

    return "Windows Terminal"
}

GetWorkspaceOpenerPlacementLabel(item) {
    monitor := GetMonitorByIndex(item["monitorIndex"])
    if !monitor {
        return "saved position"
    }

    workLeft := monitor["workLeft"]
    workTop := monitor["workTop"]
    workWidth := Max(1, monitor["workRight"] - monitor["workLeft"])
    workHeight := Max(1, monitor["workBottom"] - monitor["workTop"])
    relX := (item["x"] - workLeft) / workWidth
    relY := (item["y"] - workTop) / workHeight
    relW := item["w"] / workWidth
    relH := item["h"] / workHeight
    tolerance := 0.12

    if item["state"] = 1 || (relW >= 0.92 && relH >= 0.92) {
        return "fullscreen"
    }

    if relW <= 0.58 && relH >= 0.82 {
        if relX <= tolerance {
            return "left"
        }
        if relX + relW >= 1 - tolerance {
            return "right"
        }
    }

    if relH <= 0.58 && relW >= 0.82 {
        if relY <= tolerance {
            return "top"
        }
        if relY + relH >= 1 - tolerance {
            return "bottom"
        }
    }

    return "float"
}

LaunchSelectedWorkspaceOpener() {
    global ConfiguredPullBuilderState

    profile := FindWorkspaceOpenerProfileById(ConfiguredPullBuilderState["openerSelectedId"])
    if !profile {
        ShowThemedMessageDialog("Workspace Openers", "Select a workspace first.")
        return
    }

    launchedItems := profile["items"]
    builderOpen := ConfiguredPullBuilderState.Has("gui") && ConfiguredPullBuilderState["gui"]
    if builderOpen {
        CloseConfiguredPullBuilder()
    } else {
        CloseWorkspaceOpenerBrowser()
    }
    for _, item in launchedItems {
        LaunchWorkspaceOpenerItem(item)
    }
}

LaunchWorkspaceOpenerById(profileId, *) {
    global ConfiguredPullBuilderState

    ConfiguredPullBuilderState["openerSelectedId"] := profileId
    LaunchSelectedWorkspaceOpener()
}

LaunchWorkspaceOpenerItem(item) {
    hwnd := 0
    if StrLower(item["processName"]) = "windowsterminal.exe" {
        existingTerminalWindows := GetVisibleWindowsForProcess(item["processName"])
        if LaunchWindowsTerminalItem(item) {
            hwnd := WaitForWorkspaceItemWindow(item, 8000, existingTerminalWindows)
        }
    } else {
        hwnd := FindWorkspaceWindowForItem(item)
        if !hwnd && item.Has("path") && item["path"] != "" && IsAllowedWorkspaceAppPath(item["path"]) {
            if !LaunchWorkspaceItemPath(item["path"]) {
                try Run('"' . item["path"] . '"')
            }
            hwnd := WaitForWorkspaceItemWindow(item)
        }
    }

    if !hwnd {
        return
    }

    RestoreWindowPlacement(hwnd, Map(
        "x", item["x"],
        "y", item["y"],
        "w", item["w"],
        "h", item["h"],
        "state", item["state"]
    ))
}

LaunchWindowsTerminalItem(item) {
    launchSpec := GetWindowsTerminalLaunchSpec(item)
    if launchSpec != "" {
        try {
            Run('wt.exe -w new new-tab ' . launchSpec)
            return true
        } catch {
        }
    }

    if item.Has("profileName") && Trim(item["profileName"]) != "" {
        profileName := Trim(item["profileName"])
        try {
            Run('wt.exe -w new new-tab --profile "' . profileName . '"')
            return true
        } catch {
        }
    }

    if item.Has("title") {
        profileName := GetWindowsTerminalProfileName(item["title"])
        if profileName != "" {
            try {
                Run('wt.exe -w new new-tab --profile "' . profileName . '"')
                return true
            } catch {
            }
        }
    }

    if item.Has("path") && item["path"] != "" {
        return LaunchWorkspaceItemPath(item["path"])
    }

    try {
        Run("wt.exe -w new")
        return true
    } catch {
        return false
    }
}

GetWindowsTerminalLaunchSpec(item) {
    if !item.Has("shellKind") {
        return ""
    }

    shellKind := StrLower(Trim(item["shellKind"]))
    switch shellKind {
        case "wsl":
            distro := item.Has("wslDistro") ? Trim(item["wslDistro"]) : ""
            if distro = "" && item.Has("promptIdentity") {
                distro := ResolveWslDistroFromPrompt(item["promptIdentity"])
                if distro != "" {
                    item["wslDistro"] := distro
                }
            }
            return distro != "" ? 'wsl.exe -d "' . distro . '"' : "wsl.exe"
        case "powershell":
            return "powershell.exe"
        case "pwsh":
            return "pwsh.exe"
        case "cmd":
            return "cmd.exe"
    }

    return ""
}

IsAllowedWorkspaceAppPath(path) {
    path := Trim(path)
    if path = "" {
        return false
    }
    if IsPackagedAppPath(path) {
        return true
    }
    return FileExist(path) != ""
}

GetWindowsTerminalProfileName(title) {
    title := Trim(title)
    if title = "" {
        return ""
    }

    static ignoredTitles := Map(
        "Windows Terminal", true,
        "Administrator: Windows Terminal", true
    )
    if ignoredTitles.Has(title) {
        return ""
    }

    if RegExMatch(title, "i)^[^@]+@[^:]+:.*$") {
        return ""
    }
    if RegExMatch(title, "i)^PS .+>$") {
        return ""
    }

    return title
}

LaunchWorkspaceItemPath(path) {
    if !IsPackagedAppPath(path) {
        return false
    }

    appId := GetPackagedAppUserModelId(path)
    if appId = "" {
        return false
    }

    try {
        Run('explorer.exe "shell:AppsFolder\' . appId . '"')
        return true
    } catch {
        return false
    }
}

IsPackagedAppPath(path) {
    return InStr(path, "\WindowsApps\") > 0
}

GetPackagedAppUserModelId(path) {
    SplitPath(path, , &dir)
    if dir = "" {
        return ""
    }

    packageFullName := ""
    parts := StrSplit(dir, "\")
    for _, part in parts {
        if InStr(part, "_") && RegExMatch(part, "__[A-Za-z0-9]+$") {
            packageFullName := part
        }
    }
    if packageFullName = "" {
        return ""
    }

    if !RegExMatch(packageFullName, "^(?<name>.+?)_[^_]+_[^_]+__(?<publisher>[A-Za-z0-9]+)$", &match) {
        return ""
    }

    packageFamily := match["name"] . "_" . match["publisher"]
    return packageFamily . "!App"
}

WaitForWorkspaceItemWindow(item, timeoutMs := 8000, excludedHwnds := 0) {
    deadline := A_TickCount + timeoutMs
    while A_TickCount < deadline {
        hwnd := FindWorkspaceWindowForItem(item, excludedHwnds)
        if hwnd {
            return hwnd
        }
        Sleep(150)
    }
    return 0
}

FindWorkspaceWindowForItem(item, excludedHwnds := 0) {
    hwnds := WinGetList("ahk_exe " . item["processName"])
    for _, hwnd in hwnds {
        if excludedHwnds && excludedHwnds.Has(hwnd) {
            continue
        }

        try title := WinGetTitle("ahk_id " hwnd)
        catch
            continue

        if !DllCall("IsWindowVisible", "ptr", hwnd, "int") {
            continue
        }

        if item.Has("title") && item["title"] != "" && title = item["title"] {
            return hwnd
        }

        if item.Has("path") && item["path"] != "" {
            try currentPath := WinGetProcessPath("ahk_id " hwnd)
            if currentPath = item["path"] {
                return hwnd
            }
        }
    }

    return 0
}

GetVisibleWindowsForProcess(processName) {
    hwnds := WinGetList("ahk_exe " . processName)
    visible := Map()
    for _, hwnd in hwnds {
        try {
            if DllCall("IsWindowVisible", "ptr", hwnd, "int") {
                visible[hwnd] := true
            }
        }
    }

    return visible
}

RenameSelectedWorkspaceOpener() {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    profile := FindWorkspaceOpenerProfileById(ConfiguredPullBuilderState["openerSelectedId"])
    if !profile {
        ShowThemedMessageDialog("Workspace Openers", "Select a workspace first.")
        return
    }

    result := ShowThemedTextInputDialog("Rename Workspace", "Rename this workspace:", profile["name"])
    if result["result"] != "OK" {
        return
    }

    profile["name"] := Trim(result["value"]) != "" ? Trim(result["value"]) : profile["name"]
    SaveWorkspaceOpenerProfiles(WorkspaceOpenerProfiles)
    RefreshWorkspaceOpenerBrowser()
}

DeleteSelectedWorkspaceOpener() {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    profileId := ConfiguredPullBuilderState["openerSelectedId"]
    if profileId = "" {
        ShowThemedMessageDialog("Workspace Openers", "Select a workspace first.")
        return
    }

    result := ShowThemedMessageDialog("Delete Workspace", "Delete this saved workspace?", "YesNo")
    if result != "Yes" {
        return
    }

    removedIndex := 0
    for index, profile in WorkspaceOpenerProfiles {
        if profile["id"] = profileId {
            WorkspaceOpenerProfiles.RemoveAt(index)
            removedIndex := index
            break
        }
    }

    if WorkspaceOpenerProfiles.Length = 0 {
        ConfiguredPullBuilderState["openerSelectedId"] := ""
    } else {
        nextIndex := removedIndex - 1
        if nextIndex < 1 {
            nextIndex := 1
        }
        if nextIndex > WorkspaceOpenerProfiles.Length {
            nextIndex := WorkspaceOpenerProfiles.Length
        }
        ConfiguredPullBuilderState["openerSelectedId"] := WorkspaceOpenerProfiles[nextIndex]["id"]
        ConfiguredPullBuilderState["openerPageIndex"] := Max(Ceil(nextIndex / 6), 1)
    }

    SaveWorkspaceOpenerProfiles(WorkspaceOpenerProfiles)
    RefreshWorkspaceOpenerBrowser(ConfiguredPullBuilderState["openerPageIndex"])
}

MoveSelectedWorkspaceOpener(direction) {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    profileId := ConfiguredPullBuilderState["openerSelectedId"]
    if profileId = "" {
        ShowThemedMessageDialog("Workspace Openers", "Select a workspace first.")
        return
    }

    for index, profile in WorkspaceOpenerProfiles {
        if profile["id"] != profileId {
            continue
        }

        targetIndex := index + direction
        if targetIndex < 1 || targetIndex > WorkspaceOpenerProfiles.Length {
            return
        }

        temp := WorkspaceOpenerProfiles[index]
        WorkspaceOpenerProfiles[index] := WorkspaceOpenerProfiles[targetIndex]
        WorkspaceOpenerProfiles[targetIndex] := temp
        SaveWorkspaceOpenerProfiles(WorkspaceOpenerProfiles)
        RefreshWorkspaceOpenerBrowser()
        return
    }
}

ShowThemedTextInputDialog(title, prompt, initialValue := "") {
    global ConfiguredPullBuilderState

    uiTheme := ConfiguredPullBuilderState.Count && ConfiguredPullBuilderState.Has("uiTheme")
        ? ConfiguredPullBuilderState["uiTheme"]
        : GetUiTheme()

    ownerHwnd := 0
    if ConfiguredPullBuilderState.Count {
        if ConfiguredPullBuilderState.Has("keyboardGuiHwnd") && ConfiguredPullBuilderState["keyboardGuiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["keyboardGuiHwnd"]
        } else if ConfiguredPullBuilderState.Has("openerGuiHwnd") && ConfiguredPullBuilderState["openerGuiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["openerGuiHwnd"]
        } else if ConfiguredPullBuilderState.Has("guiHwnd") && ConfiguredPullBuilderState["guiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["guiHwnd"]
        }
    }

    options := "-Caption +Border +ToolWindow +AlwaysOnTop"
    if ownerHwnd {
        options .= " +Owner" . ownerHwnd
    }

    promptGui := Gui(options, title)
    promptGui.SetFont("s10", "Segoe UI")
    promptGui.BackColor := uiTheme["surface"]
    promptGui.MarginX := 0
    promptGui.MarginY := 0

    state := Map("result", "Cancel", "value", initialValue)

    headerBar := promptGui.AddText("x0 y0 w320 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(promptGui))
    promptGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := promptGui.AddText("x14 y9 w280 c" . uiTheme["headerText"], title)
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(promptGui))
    closeText := promptGui.AddText("x326 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")

    promptGui.SetFont("s9", "Segoe UI")
    promptText := promptGui.AddText("x18 y56 w324 h34 c" . uiTheme["text"], prompt)
    nameEdit := promptGui.AddEdit("x18 y96 w324 h28", initialValue)
    okButton := promptGui.AddButton("x162 y140 w84 h30 Default", "OK")
    cancelButton := promptGui.AddButton("x258 y140 w84 h30", "Cancel")

    closeDialog := (*) => (state["result"] := "Cancel", promptGui.Destroy())
    submitDialog := (*) => (state["result"] := "OK", state["value"] := nameEdit.Value, promptGui.Destroy())
    closeText.OnEvent("Click", closeDialog)
    cancelButton.OnEvent("Click", closeDialog)
    okButton.OnEvent("Click", submitDialog)
    promptGui.OnEvent("Close", closeDialog)
    promptGui.OnEvent("Escape", closeDialog)

    if ownerHwnd {
        WinGetPos(&ownerX, &ownerY, &ownerW, &ownerH, "ahk_id " ownerHwnd)
        promptX := ownerX + Floor((ownerW - 360) / 2)
        promptY := ownerY + Floor((ownerH - 180) / 2)
        promptGui.Show(Format("x{} y{} w360 h184", promptX, promptY))
    } else {
        promptGui.Show("w360 h184 Center")
    }

    nameEdit.Focus()
    nameEdit.Value := initialValue
    SendMessage(0xB1, 0, StrLen(initialValue), nameEdit.Hwnd)
    WinWaitClose("ahk_id " promptGui.Hwnd)
    return state
}

ShowThemedMessageDialog(title, message, mode := "OK") {
    global ConfiguredPullBuilderState

    uiTheme := ConfiguredPullBuilderState.Count && ConfiguredPullBuilderState.Has("uiTheme")
        ? ConfiguredPullBuilderState["uiTheme"]
        : GetUiTheme()

    ownerHwnd := 0
    if ConfiguredPullBuilderState.Count {
        if ConfiguredPullBuilderState.Has("keyboardGuiHwnd") && ConfiguredPullBuilderState["keyboardGuiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["keyboardGuiHwnd"]
        } else if ConfiguredPullBuilderState.Has("openerGuiHwnd") && ConfiguredPullBuilderState["openerGuiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["openerGuiHwnd"]
        } else if ConfiguredPullBuilderState.Has("guiHwnd") && ConfiguredPullBuilderState["guiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["guiHwnd"]
        }
    }

    options := "-Caption +Border +ToolWindow +AlwaysOnTop"
    if ownerHwnd {
        options .= " +Owner" . ownerHwnd
    }

    dialogGui := Gui(options, title)
    dialogGui.SetFont("s10", "Segoe UI")
    dialogGui.BackColor := uiTheme["surface"]
    dialogGui.MarginX := 0
    dialogGui.MarginY := 0

    state := Map("result", mode = "YesNo" ? "No" : "OK")

    headerBar := dialogGui.AddText("x0 y0 w320 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(dialogGui))
    dialogGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := dialogGui.AddText("x14 y9 w280 c" . uiTheme["headerText"], title)
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(dialogGui))
    closeText := dialogGui.AddText("x326 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")

    dialogGui.SetFont("s9", "Segoe UI")
    messageText := dialogGui.AddText("x18 y60 w324 h72 Center c" . uiTheme["text"], message)
    buttonsY := 144

    closeDialog := (*) => (dialogGui.Destroy())
    closeText.OnEvent("Click", closeDialog)
    dialogGui.OnEvent("Close", closeDialog)
    dialogGui.OnEvent("Escape", closeDialog)

    if mode = "YesNo" {
        yesButton := dialogGui.AddButton("x162 y144 w84 h30 Default", "Yes")
        noButton := dialogGui.AddButton("x258 y144 w84 h30", "No")
        yesButton.OnEvent("Click", (*) => (state["result"] := "Yes", dialogGui.Destroy()))
        noButton.OnEvent("Click", (*) => (state["result"] := "No", dialogGui.Destroy()))
    } else {
        okButton := dialogGui.AddButton("x258 y144 w84 h30 Default", "OK")
        okButton.OnEvent("Click", (*) => (state["result"] := "OK", dialogGui.Destroy()))
    }

    if ownerHwnd {
        WinGetPos(&ownerX, &ownerY, &ownerW, &ownerH, "ahk_id " ownerHwnd)
        dialogX := ownerX + Floor((ownerW - 360) / 2)
        dialogY := ownerY + Floor((ownerH - 184) / 2)
        dialogGui.Show(Format("x{} y{} w360 h184", dialogX, dialogY))
    } else {
        dialogGui.Show("w360 h184 Center")
    }

    WinActivate("ahk_id " dialogGui.Hwnd)
    WinWaitClose("ahk_id " dialogGui.Hwnd)
    return state["result"]
}

GetHotkeyCardEntries() {
    global SharedHotkeyRegistry
    global ConfiguredPullHotkeys

    entries := Map("shared", [], "app", [])

    for _, entry in SharedHotkeyRegistry {
        entries["shared"].Push(Map(
            "id", entry["id"],
            "hotkey", entry["hotkey"],
            "display", GetDisplayForHotkey(entry["hotkey"]),
            "action", entry["action"],
            "kind", "shared",
            "script", entry["script"],
            "disabledHotkey", entry.Has("disabledHotkey") ? entry["disabledHotkey"] : ""
        ))
    }

    for _, config in ConfiguredPullHotkeys {
        entries["app"].Push(Map(
            "hotkey", config["hotkey"],
            "display", GetDisplayForHotkey(config["hotkey"]),
            "action", GetConfiguredAppLabel(config),
            "kind", "app",
            "config", config
        ))
    }

    return entries
}

GetHotkeyViewerEntryKey(entry) {
    if entry["kind"] = "shared" {
        return entry["id"]
    }

    return entry["config"]["match"]
}

HotkeyViewerEntryMatchesSelection(entry) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return false
    }

    return ConfiguredPullBuilderState["keyboardSelectedKind"] = entry["kind"]
        && ConfiguredPullBuilderState["keyboardSelectedId"] = GetHotkeyViewerEntryKey(entry)
}

GetSelectedHotkeyViewerEntry() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return 0
    }

    selectedKind := ConfiguredPullBuilderState["keyboardSelectedKind"]
    selectedId := ConfiguredPullBuilderState["keyboardSelectedId"]
    if selectedKind = "" || selectedId = "" {
        return 0
    }

    groupedEntries := GetHotkeyCardEntries()
    for _, entry in groupedEntries["shared"] {
        if selectedKind = "shared" && entry["id"] = selectedId {
            return entry
        }
    }

    for _, entry in groupedEntries["app"] {
        if selectedKind = "app" && entry["config"]["match"] = selectedId {
            return entry
        }
    }

    return 0
}

RenderHotkeyCards(keyboardGui, uiTheme) {
    global ConfiguredPullBuilderState

    groupedEntries := GetHotkeyCardEntries()
    ConfiguredPullBuilderState["keyboardPages"] := BuildHotkeyViewerPages(groupedEntries)
    pageIndex := ConfiguredPullBuilderState["keyboardPageIndex"]
    if pageIndex < 1 || pageIndex > ConfiguredPullBuilderState["keyboardPages"].Length {
        pageIndex := 1
    }
    ConfiguredPullBuilderState["keyboardPageIndex"] := pageIndex
    RenderHotkeyViewerPage(pageIndex)
}

BuildHotkeyViewerPages(groupedEntries) {
    cols := 3
    maxRowsPerPage := 4
    pages := []
    currentPage := Map("items", [], "rows", 0)

    for _, sectionInfo in [
        Map("title", "Shared Hotkeys", "entries", groupedEntries["shared"]),
        Map("title", "App Hotkeys", "entries", groupedEntries["app"])
    ] {
        rows := []
        currentRow := []
        for _, entry in sectionInfo["entries"] {
            currentRow.Push(entry)
            if currentRow.Length = cols {
                rows.Push(currentRow)
                currentRow := []
            }
        }
        if currentRow.Length {
            rows.Push(currentRow)
        }

        rowIndex := 1
        while rowIndex <= rows.Length {
            if currentPage["rows"] = maxRowsPerPage {
                pages.Push(currentPage)
                currentPage := Map("items", [], "rows", 0)
            }

            if currentPage["items"].Length = 0 || currentPage["items"][currentPage["items"].Length]["kind"] != "section" || currentPage["items"][currentPage["items"].Length]["title"] != sectionInfo["title"] {
                currentPage["items"].Push(Map("kind", "section", "title", sectionInfo["title"]))
            }

            while rowIndex <= rows.Length && currentPage["rows"] < maxRowsPerPage {
                currentPage["items"].Push(Map("kind", "row", "entries", rows[rowIndex]))
                currentPage["rows"] += 1
                rowIndex += 1
            }

            if rowIndex <= rows.Length {
                pages.Push(currentPage)
                currentPage := Map("items", [], "rows", 0)
            }
        }
    }

    if currentPage["items"].Length {
        pages.Push(currentPage)
    }
    if pages.Length = 0 {
        pages.Push(Map("items", [], "rows", 0))
    }

    return pages
}

RenderHotkeyViewerPage(pageIndex) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count
        || !ConfiguredPullBuilderState["keyboardGuiHwnd"] {
        return
    }

    for _, ctrl in ConfiguredPullBuilderState["keyboardRenderedControls"] {
        try ctrl.Destroy()
    }
    ConfiguredPullBuilderState["keyboardRenderedControls"] := []

    pages := ConfiguredPullBuilderState["keyboardPages"]
    pageCount := pages.Length
    pageIndex := Max(Min(pageIndex, pageCount), 1)
    ConfiguredPullBuilderState["keyboardPageIndex"] := pageIndex

    keyboardGui := ConfiguredPullBuilderState["keyboardGui"]
    uiTheme := ConfiguredPullBuilderState["uiTheme"]
    rendered := []
    page := pages[pageIndex]
    y := 142
    startX := 18
    cardWidth := 168
    cardHeight := 82
    colGap := 12
    rowGap := 12
    cardControls := []

    for _, item in page["items"] {
        if item["kind"] = "section" {
            keyboardGui.SetFont("s10", "Segoe UI Semibold")
            sectionTitle := keyboardGui.AddText(Format("x{} y{} w500 c{}", startX, y, uiTheme["text"]), item["title"])
            rendered.Push(sectionTitle)
            y += 28
            continue
        }

        for col, entry in item["entries"] {
            selected := HotkeyViewerEntryMatchesSelection(entry)
            borderColor := selected
                ? uiTheme["text"]
                : (entry["kind"] = "shared" ? uiTheme["sharedBorder"] : uiTheme["appBorder"])
            fillColor := entry["kind"] = "shared" ? uiTheme["sharedFill"] : uiTheme["appFill"]
            x := startX + ((col - 1) * (cardWidth + colGap))

            cardBorder := keyboardGui.AddText(Format("x{} y{} w{} h{} Background{}", x, y, cardWidth, cardHeight, borderColor), "")
            cardFill := keyboardGui.AddText(Format("x{} y{} w{} h{} Background{} +0x200 +0x100", x + 3, y + 3, cardWidth - 6, cardHeight - 6, fillColor), "")
            comboText := keyboardGui.AddText(Format("x{} y{} w{} h20 Center c{} Background{} +0x100", x + 14, y + 12, cardWidth - 28, uiTheme["cardText"], fillColor), entry["display"])
            comboText.SetFont("s9", "Segoe UI Semibold")
            actionText := keyboardGui.AddText(Format("x{} y{} w{} h34 Center c{} Background{} +0x100", x + 14, y + 36, cardWidth - 28, uiTheme["cardText"], fillColor), entry["action"])

            selectHandler := SelectHotkeyViewerEntry.Bind(entry)
            openHandler := OpenHotkeyViewerEntry.Bind(entry)
            cardFill.OnEvent("Click", selectHandler)
            comboText.OnEvent("Click", selectHandler)
            actionText.OnEvent("Click", selectHandler)
            cardFill.OnEvent("DoubleClick", openHandler)
            comboText.OnEvent("DoubleClick", openHandler)
            actionText.OnEvent("DoubleClick", openHandler)

            rendered.Push(cardBorder)
            rendered.Push(cardFill)
            rendered.Push(comboText)
            rendered.Push(actionText)
            cardControls.Push(Map(
                "kind", entry["kind"],
                "key", GetHotkeyViewerEntryKey(entry),
                "border", cardBorder
            ))
        }
        y += cardHeight + rowGap
    }

    ConfiguredPullBuilderState["keyboardRenderedControls"] := rendered
    ConfiguredPullBuilderState["keyboardCardControls"] := cardControls
    UpdateHotkeyViewerPagination()
    UpdateHotkeyViewerActionState()
}

UpdateHotkeyViewerPagination() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    pageCount := Max(ConfiguredPullBuilderState["keyboardPages"].Length, 1)
    pageIndex := ConfiguredPullBuilderState["keyboardPageIndex"]
    ConfiguredPullBuilderState["keyboardPageLabel"].Text := "Page " . pageIndex . " of " . pageCount
    ConfiguredPullBuilderState["keyboardPrevButton"].Enabled := pageIndex > 1
    ConfiguredPullBuilderState["keyboardNextButton"].Enabled := pageIndex < pageCount
}

UpdateHotkeyViewerActionState() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["keyboardGui"] {
        return
    }

    entry := GetSelectedHotkeyViewerEntry()
    hasEntry := !!entry
    openButton := ConfiguredPullBuilderState["keyboardOpenButton"]
    actionButton := ConfiguredPullBuilderState["keyboardActionButton"]
    selectionText := ConfiguredPullBuilderState["keyboardSelectionText"]

    openButton.Enabled := hasEntry
    actionButton.Enabled := hasEntry

    if !hasEntry {
        actionButton.Text := "Delete"
        selectionText.Text := "Select a hotkey card."
        return
    }

    if entry["kind"] = "shared" {
        actionButton.Text := entry["hotkey"] = "" ? "Enable" : "Disable"
        actionButton.Enabled := true
    } else {
        actionButton.Text := "Delete"
    }

    selectionText.Text := entry["display"] . " - " . entry["action"]
}

UpdateHotkeyViewerSelectionVisuals() {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    uiTheme := ConfiguredPullBuilderState["uiTheme"]
    for _, card in ConfiguredPullBuilderState["keyboardCardControls"] {
        selected := ConfiguredPullBuilderState["keyboardSelectedKind"] = card["kind"]
            && ConfiguredPullBuilderState["keyboardSelectedId"] = card["key"]
        borderColor := selected
            ? uiTheme["text"]
            : (card["kind"] = "shared" ? uiTheme["sharedBorder"] : uiTheme["appBorder"])
        try card["border"].Opt("Background" . borderColor)
    }
}

ChangeHotkeyViewerPage(step) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    newPage := ConfiguredPullBuilderState["keyboardPageIndex"] + step
    if newPage < 1 || newPage > ConfiguredPullBuilderState["keyboardPages"].Length {
        return
    }

    ReopenHotkeyViewerPage(newPage)
}

ReopenHotkeyViewerPage(pageIndex) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count || !ConfiguredPullBuilderState["keyboardGui"] {
        return
    }

    keyboardGui := ConfiguredPullBuilderState["keyboardGui"]
    WinGetPos(&guiX, &guiY,,, "ahk_id " keyboardGui.Hwnd)
    CloseHotkeyKeyboardViewer()
    OpenHotkeyKeyboardViewer(pageIndex, Format("x{} y{} w720 h620", guiX, guiY))
}

SelectHotkeyViewerEntry(entry, *) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    ConfiguredPullBuilderState["keyboardSelectedKind"] := entry["kind"]
    ConfiguredPullBuilderState["keyboardSelectedId"] := GetHotkeyViewerEntryKey(entry)
    UpdateHotkeyViewerSelectionVisuals()
    UpdateHotkeyViewerActionState()
}

OpenHotkeyViewerEntry(entry, *) {
    SelectHotkeyViewerEntry(entry)

    if entry["kind"] = "app" {
        LoadHotkeyCardIntoBuilder(entry)
        return
    }

    LoadSharedHotkeyCardIntoBuilder(entry)
}

OpenSelectedHotkeyViewerEntry(*) {
    entry := GetSelectedHotkeyViewerEntry()
    if !entry {
        return
    }

    OpenHotkeyViewerEntry(entry)
}

PerformSelectedHotkeyViewerAction(*) {
    entry := GetSelectedHotkeyViewerEntry()
    if !entry {
        return
    }

    if entry["kind"] = "shared" {
        DisableSelectedSharedHotkey(entry)
        return
    }

    DeleteSelectedAppHotkey(entry)
}

DeleteSelectedAppHotkey(entry) {
    global ConfiguredPullBuilderState
    global ConfiguredPullHotkeys

    result := ShowThemedMessageDialog("Delete Hotkey", "Delete " . entry["display"] . " for " . entry["action"] . "?", "YesNo")
    if result != "Yes" {
        return
    }

    deleteIndex := FindConfiguredPullIndexByMatch(entry["config"]["match"])
    if !deleteIndex {
        return
    }

    try Hotkey(entry["config"]["hotkey"], "Off")
    ConfiguredPullHotkeys.RemoveAt(deleteIndex)
    SaveConfiguredPullHotkeys(ConfiguredPullHotkeys)

    ConfiguredPullBuilderState["keyboardSelectedKind"] := ""
    ConfiguredPullBuilderState["keyboardSelectedId"] := ""
    RenderHotkeyCards(ConfiguredPullBuilderState["keyboardGui"], ConfiguredPullBuilderState["uiTheme"])
}

DisableSelectedSharedHotkey(entry) {
    global ConfiguredPullBuilderState
    global SharedHotkeyRegistry

    sharedIndex := FindSharedRegistryIndexById(entry["id"])
    if !sharedIndex {
        return
    }

    currentHotkey := SharedHotkeyRegistry[sharedIndex]["hotkey"]
    if currentHotkey = "" {
        restoredHotkey := SharedHotkeyRegistry[sharedIndex].Has("disabledHotkey")
            ? SharedHotkeyRegistry[sharedIndex]["disabledHotkey"]
            : GetDefaultSharedHotkey(entry["id"])
        if restoredHotkey = "" {
            return
        }

        SharedHotkeyRegistry[sharedIndex]["hotkey"] := restoredHotkey
        SharedHotkeyRegistry[sharedIndex]["disabledHotkey"] := ""
        ApplySharedHotkeyLiveState(entry["id"], restoredHotkey, true)
    } else {
        ApplySharedHotkeyLiveState(entry["id"], currentHotkey, false)
        SharedHotkeyRegistry[sharedIndex]["disabledHotkey"] := currentHotkey
        SharedHotkeyRegistry[sharedIndex]["hotkey"] := ""
    }

    SaveSharedHotkeyRegistry(SharedHotkeyRegistry)

    ConfiguredPullBuilderState["keyboardSelectedKind"] := "shared"
    ConfiguredPullBuilderState["keyboardSelectedId"] := entry["id"]
    RenderHotkeyCards(ConfiguredPullBuilderState["keyboardGui"], ConfiguredPullBuilderState["uiTheme"])
}

GetDefaultSharedHotkey(id) {
    for _, entry in DefaultSharedHotkeyRegistry() {
        if entry["id"] = id {
            return entry["hotkey"]
        }
    }

    return ""
}

ApplySharedHotkeyLiveState(sharedId, hotkey, enable) {
    switch sharedId {
        case "wm.move-left":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.move-right":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.move-left-center":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.move-right-center":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.open-builder":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.open-opener":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.pull-recent":
            Hotkey(hotkey, enable ? "On" : "Off")
        case "wm.toggle-suspend":
            Hotkey(hotkey, enable ? "On" : "Off")
        default:
            ReloadExternalSharedHotkeyScript(sharedId)
    }
}

ReloadExternalSharedHotkeyScript(sharedId) {
    scriptPath := ""
    switch sharedId {
        case "fullscreen.toggle":
            scriptPath := A_ScriptDir "\fullscreen.ahk"
        case "kill.close-active":
            scriptPath := A_ScriptDir "\kill.ahk"
    }

    if scriptPath = "" || !FileExist(scriptPath) {
        return
    }

    try Run('"' . A_AhkPath . '" "' . scriptPath . '"')
}

GetUiTheme() {
    try {
        appsUseLightTheme := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    } catch {
        appsUseLightTheme := 1
    }

    if appsUseLightTheme = 0 {
        return Map(
            "surface", "1E1F22",
            "title", "F9FAFB",
            "text", "F3F4F6",
            "muted", "A1A1AA",
            "section", "C7CDD6",
            "input", "2B2D31",
            "danger", "FCA5A5",
            "dangerFill", "40262B",
            "header", "1E1F22",
            "headerText", "F9FAFB",
            "closeFill", "B42318",
            "scrollTrack", "0F1012",
            "scrollThumb", "737983",
            "sharedBorder", "636873",
            "sharedFill", "1E1F22",
            "appBorder", "5E8A68",
            "appFill", "1E1F22",
            "cardText", "F3F4F6"
        )
    }

    return Map(
        "surface", "F5F7FA",
        "title", "16202A",
        "text", "111827",
        "muted", "6B7280",
        "section", "94A3B8",
        "input", "FFFFFF",
        "danger", "B42318",
        "dangerFill", "FDE8E8",
        "header", "F5F7FA",
        "headerText", "16202A",
        "closeFill", "D14D41",
        "scrollTrack", "D1D5DB",
        "scrollThumb", "6B7280",
        "sharedBorder", "A5AFBE",
        "sharedFill", "F5F7FA",
        "appBorder", "6BA07A",
        "appFill", "F5F7FA",
        "cardText", "111827"
    )
}

LoadHotkeyCardIntoBuilder(entry, *) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    config := entry["config"]
    windowInfo := Map(
        "match", config["match"],
        "label", GetConfiguredAppLabel(config)
    )
    SetConfiguredPullBuilderEditingMode("app", windowInfo)
    ApplyHotkeyToBuilderControls(config["hotkey"])

    if GetMainMonitorAction(config) = "focus-last" {
        ConfiguredPullBuilderState["mainRadio"].Value := 1
        ConfiguredPullBuilderState["burnerRadio"].Value := 0
    } else {
        ConfiguredPullBuilderState["mainRadio"].Value := 0
        ConfiguredPullBuilderState["burnerRadio"].Value := 1
    }

    UpdateConfiguredPullBuilderConflictState()
    CloseHotkeyKeyboardViewer()
    ConfiguredPullBuilderState["gui"].Show()
}

LoadSharedHotkeyCardIntoBuilder(entry, *) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    sharedInfo := Map(
        "match", entry["script"],
        "label", entry["action"]
    )
    SetConfiguredPullBuilderEditingMode("shared", sharedInfo, entry["id"])
    ApplyHotkeyToBuilderControls(entry["hotkey"])
    CloseHotkeyKeyboardViewer()
    ConfiguredPullBuilderState["gui"].Show()
}

ApplyHotkeyToBuilderControls(hotkey) {
    global ConfiguredPullBuilderState

    parts := ParseHotkeyForBuilder(hotkey)
    if !parts {
        return
    }

    ConfiguredPullBuilderState["winCheckbox"].Value := parts["win"]
    ConfiguredPullBuilderState["ctrlCheckbox"].Value := parts["ctrl"]
    ConfiguredPullBuilderState["altCheckbox"].Value := parts["alt"]
    ConfiguredPullBuilderState["shiftCheckbox"].Value := parts["shift"]
    SetConfiguredPullBuilderHotkey(hotkey, GetDisplayForHotkey(hotkey))
}

ParseHotkeyForBuilder(hotkey) {
    parts := Map(
        "win", 0,
        "ctrl", 0,
        "alt", 0,
        "shift", 0
    )

    while hotkey != "" {
        prefix := SubStr(hotkey, 1, 1)
        if prefix = "#" {
            parts["win"] := 1
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "^" {
            parts["ctrl"] := 1
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "!" {
            parts["alt"] := 1
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "+" {
            parts["shift"] := 1
            hotkey := SubStr(hotkey, 2)
            continue
        }

        break
    }

    if hotkey = "" {
        return 0
    }

    return parts
}

GetDisplayForHotkey(hotkey) {
    if hotkey = "" {
        return "None"
    }

    displayParts := []

    while hotkey != "" {
        prefix := SubStr(hotkey, 1, 1)
        if prefix = "#" {
            displayParts.Push("Win")
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "^" {
            displayParts.Push("Ctrl")
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "!" {
            displayParts.Push("Alt")
            hotkey := SubStr(hotkey, 2)
            continue
        }
        if prefix = "+" {
            displayParts.Push("Shift")
            hotkey := SubStr(hotkey, 2)
            continue
        }

        break
    }

    if hotkey != "" {
        displayParts.Push(GetHotkeyDisplayName(hotkey))
    }

    return JoinDisplayParts(displayParts)
}

JoinDisplayParts(parts) {
    text := ""
    for _, part in parts {
        text .= (text = "" ? "" : "+") . part
    }

    return text
}

SaveConfiguredPullBuilder() {
    global ConfiguredPullBuilderState
    global ConfiguredPullHotkeys
    global SharedHotkeyRegistry

    if !ConfiguredPullBuilderState.Count {
        return
    }

    selectedHotkey := ConfiguredPullBuilderState["selectedHotkey"]
    selectedHotkeyDisplay := ConfiguredPullBuilderState["selectedHotkeyDisplay"]
    if selectedHotkey = "" {
        MsgBox("Press a key combo for the new hotkey first. Press Esc if you want to clear and choose again.", "Create App Hotkey")
        return
    }

    editingKind := ConfiguredPullBuilderState["editingKind"]
    currentMatch := editingKind = "app" ? ConfiguredPullBuilderState["windowInfo"]["match"] : ""
    currentSharedId := editingKind = "shared" ? ConfiguredPullBuilderState["editingSharedId"] : ""
    conflict := FindConfiguredPullBuilderConflict(selectedHotkey, editingKind, currentMatch, currentSharedId)

    if conflict {
        result := MsgBox(
            selectedHotkeyDisplay . " is already assigned to " . conflict["label"] . "." . "`n`n" . "Are you sure you would like to overwrite it?",
            "Confirm Hotkey Overwrite",
            "YesNo"
        )
        if result != "Yes" {
            return
        }
    }

    if editingKind = "shared" {
        SaveSharedHotkeyBuilderSelection(selectedHotkey, conflict)
        return
    }

    windowInfo := ConfiguredPullBuilderState["windowInfo"]
    newConfig := BuildConfiguredPullConfig(windowInfo, selectedHotkey, ConfiguredPullBuilderState["mainRadio"].Value = 1)
    sameAppIndex := FindConfiguredPullIndexByMatch(windowInfo["match"])
    collisionIndex := conflict && conflict["type"] = "app" ? conflict["index"] : 0

    if collisionIndex && collisionIndex != sameAppIndex {
        ConfiguredPullHotkeys.RemoveAt(collisionIndex)
        if sameAppIndex > collisionIndex {
            sameAppIndex -= 1
        }
    }

    if sameAppIndex {
        ConfiguredPullHotkeys[sameAppIndex] := newConfig
    } else {
        ConfiguredPullHotkeys.Push(newConfig)
    }

    SaveConfiguredPullHotkeys(ConfiguredPullHotkeys)
    CloseConfiguredPullBuilder()
    Reload()
}

SaveSharedHotkeyBuilderSelection(selectedHotkey, conflict := 0) {
    global ConfiguredPullBuilderState
    global SharedHotkeyRegistry
    global ConfiguredPullHotkeys

    currentSharedId := ConfiguredPullBuilderState["editingSharedId"]
    sharedIndex := FindSharedRegistryIndexById(currentSharedId)
    if !sharedIndex {
        return
    }

    if conflict {
        if conflict["type"] = "shared" {
            otherIndex := FindSharedRegistryIndexById(conflict["id"])
            if otherIndex {
                SharedHotkeyRegistry[otherIndex]["hotkey"] := ""
            }
        } else if conflict["type"] = "app" {
            ConfiguredPullHotkeys.RemoveAt(conflict["index"])
            SaveConfiguredPullHotkeys(ConfiguredPullHotkeys)
        }
    }

    SharedHotkeyRegistry[sharedIndex]["hotkey"] := selectedHotkey
    SaveSharedHotkeyRegistry(SharedHotkeyRegistry)
    CloseConfiguredPullBuilder()
    Reload()
}

BuildConfiguredPullConfig(windowInfo, hotkey, useMainMonitorConfig) {
    config := Map(
        "hotkey", hotkey,
        "match", windowInfo["match"],
        "label", windowInfo["label"]
    )

    if useMainMonitorConfig {
        config["mainMonitorAction"] := "focus-last"
        return config
    }

    config["mainMonitorAction"] := "burner"
    config["burnerLayout"] := "float"
    return config
}

GetActiveConfiguredWindowInfo() {
    hwnd := WinExist("A")
    if !hwnd {
        return 0
    }

    try {
        processName := WinGetProcessName("ahk_id " hwnd)
    } catch {
        return 0
    }

    if processName = "" {
        return 0
    }

    title := WinGetTitle("ahk_id " hwnd)
    return Map(
        "match", "ahk_exe " . processName,
        "label", title != "" ? title : RegExReplace(processName, "\.exe$", "")
    )
}

FindConfiguredPullIndexByHotkey(hotkey) {
    global ConfiguredPullHotkeys

    for index, config in ConfiguredPullHotkeys {
        if config["hotkey"] = hotkey {
            return index
        }
    }

    return 0
}

FindConfiguredPullIndexByMatch(match) {
    global ConfiguredPullHotkeys

    for index, config in ConfiguredPullHotkeys {
        if config["match"] = match {
            return index
        }
    }

    return 0
}

GetConfiguredAppLabel(config) {
    if config.Has("label") && config["label"] != "" {
        return config["label"]
    }

    if config.Has("match") {
        return config["match"]
    }

    return "this app"
}

ToggleWindowManagerSuspend(*) {
    Suspend(-1)
    TrayTip("Window Manager", A_IsSuspended ? "Hotkeys disabled" : "Hotkeys enabled")
}

HandleConfiguredPullHotkeyDown(config, *) {
    global ConfiguredPullHotkeyState

    stateKey := GetConfiguredPullStateKey(config)
    if ConfiguredPullHotkeyState.Has(stateKey) {
        return
    }

    MouseGetPos(&mouseX, &mouseY)
    keyName := GetConfiguredPullPrimaryKey(config["hotkey"])
    if !keyName {
        return
    }

    ConfiguredPullHotkeyState[stateKey] := Map(
        "mouseX", mouseX,
        "mouseY", mouseY,
        "keyName", keyName,
        "startTick", A_TickCount,
        "holdTriggered", false,
        "timer", ""
    )

    timer := MonitorConfiguredPullHotkey.Bind(stateKey, config)
    ConfiguredPullHotkeyState[stateKey]["timer"] := timer
    SetTimer(timer, 25)
}

MonitorConfiguredPullHotkey(stateKey, config) {
    global ConfiguredPullHotkeyState
    global ConfiguredPullHoldDelayMs

    if !ConfiguredPullHotkeyState.Has(stateKey) {
        return
    }

    state := ConfiguredPullHotkeyState[stateKey]

    if !GetKeyState(state["keyName"], "P") {
        SetTimer(state["timer"], 0)
        ConfiguredPullHotkeyState.Delete(stateKey)

        if !state["holdTriggered"] {
            PullConfiguredWindow(config)
        }
        return
    }

    if state["holdTriggered"] {
        return
    }

    if (A_TickCount - state["startTick"]) < ConfiguredPullHoldDelayMs {
        return
    }

    state["holdTriggered"] := true
    ConfiguredPullHotkeyState[stateKey] := state
    PullConfiguredWindow(config, true, state["mouseX"], state["mouseY"])
}

GetConfiguredPullStateKey(config) {
    return config.Has("hotkey") ? config["hotkey"] : config["match"]
}

GetConfiguredPullPrimaryKey(hotkey) {
    hotkey := Trim(hotkey)
    if !hotkey {
        return ""
    }

    if InStr(hotkey, "&") {
        parts := StrSplit(hotkey, "&")
        return Trim(parts[parts.Length])
    }

    while hotkey != "" {
        prefix := SubStr(hotkey, 1, 1)
        if InStr("*~$<>#^!+", prefix) {
            hotkey := SubStr(hotkey, 2)
            continue
        }

        break
    }

    return Trim(hotkey)
}

PullConfiguredWindow(config, tileOnPullToMain := false, mouseX := "", mouseY := "", *) {
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

    if tileOnPullToMain {
        if !WinActive("ahk_id " hwnd) {
            StoreConfiguredPreviousWindow(config, WinExist("A"), hwnd)
        }

        WinActivate("ahk_id " hwnd)
        ApplyTilePullToMain(hwnd, source, primary, mouseX, mouseY)
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

ApplyTilePullToMain(hwnd, source, primary, mouseX, mouseY) {
    direction := GetMouseDrivenTileDirection(primary, mouseX, mouseY)

    ApplyTileOnMonitor(hwnd, primary, direction)
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

PullMostRecentWindow(*) {
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
    ApplyTileOnMonitor(hwnd, monitor, direction)
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
    halfHeight := Floor(workHeight / 2)

    if direction = "left" {
        newX := workLeft
        newY := workTop
        newW := halfWidth
        newH := workHeight
    } else if direction = "right" {
        newX := workLeft + halfWidth
        newY := workTop
        newW := workWidth - halfWidth
        newH := workHeight
    } else if direction = "up" {
        newX := workLeft
        newY := workTop
        newW := workWidth
        newH := halfHeight
    } else {
        newX := workLeft
        newY := workTop + halfHeight
        newW := workWidth
        newH := workHeight - halfHeight
    }

    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)
}

GetMouseDrivenTileDirection(monitor, mouseX := "", mouseY := "") {
    if mouseX = "" || mouseY = "" {
        MouseGetPos(&mouseX, &mouseY)
    }

    if IsPortraitMonitor(monitor) {
        midY := monitor["workTop"] + ((monitor["workBottom"] - monitor["workTop"]) / 2)
        return mouseY < midY ? "up" : "down"
    }

    midX := monitor["workLeft"] + ((monitor["workRight"] - monitor["workLeft"]) / 2)
    return mouseX < midX ? "left" : "right"
}

IsPortraitMonitor(monitor) {
    width := monitor["workRight"] - monitor["workLeft"]
    height := monitor["workBottom"] - monitor["workTop"]
    return height > width
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
