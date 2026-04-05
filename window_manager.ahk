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
global SharedHotkeyRegistry := InitializeSharedHotkeyRegistry()
global ConfiguredPullHotkeys := InitializeConfiguredPullHotkeys()

#x::MoveWindowDirection("left", false)
#c::MoveWindowDirection("right", false)
#^x::MoveWindowDirection("left", true)
#^c::MoveWindowDirection("right", true)
#b::OpenConfiguredHotkeyBuilder()
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
    hotkeyHintText := builderGui.AddText(Format("x{} y244 w260 c{}", left + 256, uiTheme["muted"]), "Press any key to begin. Press Esc to clear the selected hotkey.")
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

    applyButton := builderGui.AddButton(Format("x{} y472 w104 h30 Default", left), "Apply")
    cancelButton := builderGui.AddButton(Format("x{} y472 w104 h30", left + 118), "Cancel")
    hotkeysButton := builderGui.AddButton(Format("x{} y472 w104 h30", left + 236), "Hotkeys")
    applyButton.OnEvent("Click", (*) => SaveConfiguredPullBuilder())
    cancelButton.OnEvent("Click", (*) => CloseConfiguredPullBuilder())
    hotkeysButton.OnEvent("Click", (*) => ToggleHotkeyKeyboardViewer())

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
    builderGui.Show("w560 h526 Center")
    winCheckbox.Focus()
}

CloseConfiguredPullBuilder() {
    global ConfiguredPullBuilderState

    CloseHotkeyKeyboardViewer()

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

    if WinExist("A") != ConfiguredPullBuilderState["guiHwnd"] {
        return
    }

    keyName := NormalizeBuilderKeyName(wParam, lParam)
    if keyName = "" {
        return 0
    }

    if keyName = "Escape" {
        SetConfiguredPullBuilderHotkey("", "")
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
        || !ConfiguredPullBuilderState["keyboardGuiHwnd"] {
        return
    }

    MouseGetPos(, , &winHwnd,, 2)
    if winHwnd != ConfiguredPullBuilderState["keyboardGuiHwnd"] {
        return
    }

    delta := wParam >> 16
    if delta > 0x7FFF {
        delta -= 0x10000
    }

    if delta > 0 {
        ChangeHotkeyViewerPage(-1)
    } else if delta < 0 {
        ChangeHotkeyViewerPage(1)
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
        "Ctrl", true,
        "LCtrl", true,
        "RCtrl", true,
        "Alt", true,
        "LAlt", true,
        "RAlt", true,
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

SetConfiguredPullBuilderHotkey(hotkey, display) {
    global ConfiguredPullBuilderState

    if !ConfiguredPullBuilderState.Count {
        return
    }

    ConfiguredPullBuilderState["selectedHotkey"] := hotkey
    ConfiguredPullBuilderState["selectedHotkeyDisplay"] := display
    ConfiguredPullBuilderState["selectedKeyText"].Text := display
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

    headerBar := keyboardGui.AddText("x0 y0 w676 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(keyboardGui))
    keyboardGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := keyboardGui.AddText("x14 y9 w600 c" . uiTheme["headerText"], "Current Hotkeys")
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(keyboardGui))
    closeButton := keyboardGui.AddText("x682 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")
    closeButton.OnEvent("Click", (*) => CloseHotkeyKeyboardViewer())

    keyboardGui.SetFont("s9", "Segoe UI")
    keyboardGui.AddText("x18 y58 w676 h34 c" . uiTheme["muted"], "Click a card to load it into the editor. Shared script hotkeys are gray, app hotkeys are green.")

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
    ConfiguredPullBuilderState["keyboardPageIndex"] := initialPage
    ConfiguredPullBuilderState["keyboardPages"] := []
    ConfiguredPullBuilderState["keyboardRenderedControls"] := []

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
        ConfiguredPullBuilderState["keyboardPageIndex"] := 1
        ConfiguredPullBuilderState["keyboardPages"] := []
        ConfiguredPullBuilderState["keyboardRenderedControls"] := []
    }
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
            "script", entry["script"]
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
    y := 102
    startX := 18
    cardWidth := 168
    cardHeight := 82
    colGap := 12
    rowGap := 12

    for _, item in page["items"] {
        if item["kind"] = "section" {
            keyboardGui.SetFont("s10", "Segoe UI Semibold")
            sectionTitle := keyboardGui.AddText(Format("x{} y{} w500 c{}", startX, y, uiTheme["text"]), item["title"])
            rendered.Push(sectionTitle)
            y += 28
            continue
        }

        for col, entry in item["entries"] {
            borderColor := entry["kind"] = "shared" ? uiTheme["sharedBorder"] : uiTheme["appBorder"]
            fillColor := entry["kind"] = "shared" ? uiTheme["sharedFill"] : uiTheme["appFill"]
            x := startX + ((col - 1) * (cardWidth + colGap))

            cardBorder := keyboardGui.AddText(Format("x{} y{} w{} h{} Background{}", x, y, cardWidth, cardHeight, borderColor), "")
            cardFill := keyboardGui.AddText(Format("x{} y{} w{} h{} Background{} +0x200 +0x100", x + 3, y + 3, cardWidth - 6, cardHeight - 6, fillColor), "")
            comboText := keyboardGui.AddText(Format("x{} y{} w{} h20 Center c{} Background{} +0x100", x + 14, y + 12, cardWidth - 28, uiTheme["cardText"], fillColor), entry["display"])
            comboText.SetFont("s9", "Segoe UI Semibold")
            actionText := keyboardGui.AddText(Format("x{} y{} w{} h34 Center c{} Background{} +0x100", x + 14, y + 36, cardWidth - 28, uiTheme["cardText"], fillColor), entry["action"])

            if entry["kind"] = "app" {
                cardFill.OnEvent("Click", LoadHotkeyCardIntoBuilder.Bind(entry))
                comboText.OnEvent("Click", LoadHotkeyCardIntoBuilder.Bind(entry))
                actionText.OnEvent("Click", LoadHotkeyCardIntoBuilder.Bind(entry))
            } else {
                cardFill.OnEvent("Click", LoadSharedHotkeyCardIntoBuilder.Bind(entry))
                comboText.OnEvent("Click", LoadSharedHotkeyCardIntoBuilder.Bind(entry))
                actionText.OnEvent("Click", LoadSharedHotkeyCardIntoBuilder.Bind(entry))
            }

            rendered.Push(cardBorder)
            rendered.Push(cardFill)
            rendered.Push(comboText)
            rendered.Push(actionText)
        }
        y += cardHeight + rowGap
    }

    ConfiguredPullBuilderState["keyboardRenderedControls"] := rendered
    UpdateHotkeyViewerPagination()
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
        return "Unassigned"
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
