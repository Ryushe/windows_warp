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
        "settingsGui", 0,
        "settingsGuiHwnd", 0,
        "workspaceCaptureGuiHwnd", 0,
        "workspaceCaptureApplyFn", 0,
        "workspaceCaptureToggleFn", 0,
        "textInputGuiHwnd", 0,
        "textInputApplyFn", 0,
        "workspacePickerGuiHwnd", 0,
        "workspacePickerApplyFn", 0,
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

    newButton := openerGui.AddButton("x18 y104 w86 h30", "New")
    updateButton := openerGui.AddButton("x114 y104 w86 h30", "Update")
    launchButton := openerGui.AddButton("x210 y104 w86 h30", "Launch")
    renameButton := openerGui.AddButton("x306 y104 w86 h30", "Rename")
    deleteButton := openerGui.AddButton("x402 y104 w86 h30", "Delete")

    newButton.OnEvent("Click", (*) => OpenWorkspaceNewDialog())
    updateButton.OnEvent("Click", (*) => OpenWorkspaceUpdateDialog())
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
    ConfiguredPullBuilderState["openerNewButton"] := newButton
    ConfiguredPullBuilderState["openerUpdateButton"] := updateButton
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
        ConfiguredPullBuilderState["openerNewButton"] := 0
        ConfiguredPullBuilderState["openerUpdateButton"] := 0
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

BuildWorkspaceAppCounts(items) {
    counts := Map()
    for _, item in items {
        processName := StrLower(item["processName"])
        counts[processName] := counts.Has(processName) ? counts[processName] + 1 : 1
    }
    return counts
}

GetWorkspaceOverlapScore(currentCounts, profile) {
    profileCounts := BuildWorkspaceAppCounts(profile["items"])
    score := 0
    for processName, currentCount in currentCounts {
        if profileCounts.Has(processName) {
            score += Min(currentCount, profileCounts[processName]) * 20
        }
    }
    return score
}

GetBestWorkspaceUpdateGuessId(currentItems) {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles
    global LastLaunchedWorkspaceId
    global LastUpdatedWorkspaceId

    if WorkspaceOpenerProfiles.Length = 0 {
        return ""
    }

    currentCounts := BuildWorkspaceAppCounts(currentItems)
    selectedId := ConfiguredPullBuilderState.Count && ConfiguredPullBuilderState.Has("openerSelectedId")
        ? ConfiguredPullBuilderState["openerSelectedId"]
        : ""

    bestId := WorkspaceOpenerProfiles[1]["id"]
    bestScore := -1
    for _, profile in WorkspaceOpenerProfiles {
        score := GetWorkspaceOverlapScore(currentCounts, profile)
        if selectedId != "" && profile["id"] = selectedId {
            score += 100
        }
        if LastLaunchedWorkspaceId != "" && profile["id"] = LastLaunchedWorkspaceId {
            score += 80
        }
        if LastUpdatedWorkspaceId != "" && profile["id"] = LastUpdatedWorkspaceId {
            score += 60
        }

        if score > bestScore {
            bestScore := score
            bestId := profile["id"]
        }
    }

    return bestId
}

OpenWorkspaceUpdateDialog(*) {
    OpenWorkspaceCaptureDialog("update")
}

UpdateWorkspaceProfile(profileId, items := 0) {
    global WorkspaceOpenerProfiles
    global ConfiguredPullBuilderState
    global LastUpdatedWorkspaceId

    profileIndex := FindWorkspaceOpenerProfileIndexById(profileId)
    if !profileIndex {
        return
    }

    if !items {
        items := CaptureCurrentWorkspaceItems()
        if items.Length = 0 {
            ShowThemedMessageDialog("Update Workspace", "No normal application windows were found to capture.")
            return
        }
    }

    WorkspaceOpenerProfiles[profileIndex]["items"] := items
    SaveWorkspaceOpenerProfiles(WorkspaceOpenerProfiles)
    LastUpdatedWorkspaceId := profileId
    ConfiguredPullBuilderState["openerSelectedId"] := profileId
    RefreshWorkspaceOpenerBrowser()
}

FindWorkspaceOpenerProfileIndexById(profileId) {
    global WorkspaceOpenerProfiles

    for index, profile in WorkspaceOpenerProfiles {
        if profile["id"] = profileId {
            return index
        }
    }

    return 0
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

OpenWorkspaceNewDialog(*) {
    OpenWorkspaceCaptureDialog("create")
}

OpenWorkspaceCaptureDialog(initialMode := "create") {
    global WorkspaceOpenerProfiles
    global ConfiguredPullBuilderState

    currentItems := CaptureCurrentWorkspaceItems()
    if currentItems.Length = 0 {
        ShowThemedMessageDialog("Capture Workspace", "No normal application windows were found to capture.")
        return
    }

    defaultName := "Workspace " . (WorkspaceOpenerProfiles.Length + 1)
    guessedId := GetBestWorkspaceUpdateGuessId(currentItems)
    result := ShowThemedWorkspaceCaptureDialog(initialMode, defaultName, guessedId)
    if result["result"] != "OK" {
        return
    }

    if result["mode"] = "update" {
        if result["profileId"] = "" {
            return
        }
        UpdateWorkspaceProfile(result["profileId"], currentItems)
        return
    }

    profileId := "workspace-" . A_Now . "-" . Random(100, 999)
    WorkspaceOpenerProfiles.Push(Map(
        "id", profileId,
        "name", Trim(result["value"]) != "" ? Trim(result["value"]) : defaultName,
        "items", currentItems
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
    global LastLaunchedWorkspaceId

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
    LastLaunchedWorkspaceId := profile["id"]
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


ShowThemedWorkspaceCaptureDialog(initialMode := "create", defaultName := "", initialProfileId := "") {
    global ConfiguredPullBuilderState
    global WorkspaceOpenerProfiles

    uiTheme := ConfiguredPullBuilderState.Count && ConfiguredPullBuilderState.Has("uiTheme")
        ? ConfiguredPullBuilderState["uiTheme"]
        : GetUiTheme()

    ownerHwnd := 0
    if ConfiguredPullBuilderState.Count {
        if ConfiguredPullBuilderState.Has("openerGuiHwnd") && ConfiguredPullBuilderState["openerGuiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["openerGuiHwnd"]
        } else if ConfiguredPullBuilderState.Has("guiHwnd") && ConfiguredPullBuilderState["guiHwnd"] {
            ownerHwnd := ConfiguredPullBuilderState["guiHwnd"]
        }
    }

    options := "-Caption +Border +ToolWindow +AlwaysOnTop"
    if ownerHwnd {
        options .= " +Owner" . ownerHwnd
    }

    captureGui := Gui(options, "Capture Workspace")
    captureGui.SetFont("s10", "Segoe UI")
    captureGui.BackColor := uiTheme["surface"]
    captureGui.MarginX := 0
    captureGui.MarginY := 0

    state := Map("result", "Cancel", "mode", "create", "value", defaultName, "profileId", "")
    labels := []
    profileIds := []
    initialIndex := 1
    hasProfiles := WorkspaceOpenerProfiles.Length > 0
    for index, profile in WorkspaceOpenerProfiles {
        labels.Push(profile["name"])
        profileIds.Push(profile["id"])
        if initialProfileId != "" && profile["id"] = initialProfileId {
            initialIndex := index
        }
    }

    mode := StrLower(initialMode)
    if mode != "update" {
        mode := "create"
    }
    if !hasProfiles {
        mode := "create"
    }

    headerBar := captureGui.AddText("x0 y0 w468 h38 Background" . uiTheme["header"], "")
    headerBar.OnEvent("Click", (*) => StartGuiDrag(captureGui))
    captureGui.SetFont("s11", "Segoe UI Semibold")
    headerTitle := captureGui.AddText("x14 y9 w372 c" . uiTheme["headerText"], "Capture Workspace")
    headerTitle.OnEvent("Click", (*) => StartGuiDrag(captureGui))
    closeText := captureGui.AddText("x434 y5 w24 h26 Center c" . uiTheme["headerText"] . " Background" . uiTheme["closeFill"] . " +0x200 Border", "X")

    captureGui.SetFont("s9", "Segoe UI")
    captureGui.AddText("x18 y60 w410 h18 c" . uiTheme["text"], "Choose whether to create a new workspace or update an existing one.")
    createRadio := captureGui.AddRadio(Format("x18 y96 w90 h22 {} c{}", mode = "create" ? "Checked" : "", uiTheme["text"]), "Create")
    updateRadio := captureGui.AddRadio(Format("x126 y96 w90 h22 {} c{}", mode = "update" ? "Checked" : "", uiTheme["text"]), "Update")
    helperText := captureGui.AddText("x18 y128 w410 h18 c" . uiTheme["muted"], "")
    nameEdit := captureGui.AddEdit("x18 y156 w410 h28", defaultName)
    workspaceDropDown := captureGui.AddDropDownList("x18 y156 w410 Choose" . initialIndex, labels)
    applyButton := captureGui.AddButton("x222 y206 w96 h30 Default", "Apply")
    cancelButton := captureGui.AddButton("x332 y206 w96 h30", "Cancel")

    setMode := 0
    setMode := (newMode) => (
        state["mode"] := (!hasProfiles && newMode = "update") ? "create" : newMode,
        createRadio.Value := state["mode"] = "create" ? 1 : 0,
        updateRadio.Value := state["mode"] = "update" ? 1 : 0,
        helperText.Text := state["mode"] = "create"
            ? "Type a workspace name, then press Enter to save it."
            : "Use " . Chr(8593) . " and " . Chr(8595) . " to choose a workspace, then press Enter to update it.",
        nameEdit.Visible := state["mode"] = "create",
        workspaceDropDown.Visible := state["mode"] = "update",
        state["mode"] = "create" ? nameEdit.Focus() : workspaceDropDown.Focus()
    )

    clearDialogState := () => (
        ConfiguredPullBuilderState["workspaceCaptureGuiHwnd"] := 0,
        ConfiguredPullBuilderState["workspaceCaptureApplyFn"] := 0,
        ConfiguredPullBuilderState["workspaceCaptureToggleFn"] := 0
    )
    closeDialog := (*) => (state["result"] := "Cancel", clearDialogState(), captureGui.Destroy())
    applyDialog := (*) => (
        state["result"] := "OK",
        state["value"] := nameEdit.Value,
        state["profileId"] := (state["mode"] = "update" && workspaceDropDown.Value >= 1 && workspaceDropDown.Value <= profileIds.Length) ? profileIds[workspaceDropDown.Value] : "",
        clearDialogState(),
        captureGui.Destroy()
    )

    createRadio.OnEvent("Click", (*) => setMode("create"))
    updateRadio.OnEvent("Click", (*) => setMode("update"))
    closeText.OnEvent("Click", closeDialog)
    cancelButton.OnEvent("Click", closeDialog)
    applyButton.OnEvent("Click", applyDialog)
    captureGui.OnEvent("Close", closeDialog)
    captureGui.OnEvent("Escape", closeDialog)

    if ownerHwnd {
        WinGetPos(&ownerX, &ownerY, &ownerW, &ownerH, "ahk_id " ownerHwnd)
        dialogX := ownerX + Floor((ownerW - 468) / 2)
        dialogY := ownerY + Floor((ownerH - 254) / 2)
        captureGui.Show(Format("x{} y{} w468 h254", dialogX, dialogY))
    } else {
        captureGui.Show("w468 h254 Center")
    }

    ConfiguredPullBuilderState["workspaceCaptureGuiHwnd"] := captureGui.Hwnd
    ConfiguredPullBuilderState["workspaceCaptureApplyFn"] := applyDialog
    ConfiguredPullBuilderState["workspaceCaptureToggleFn"] := setMode
    setMode(mode)
    if state["mode"] = "create" {
        nameEdit.Value := defaultName
        SendMessage(0xB1, 0, StrLen(defaultName), nameEdit.Hwnd)
    }
    WinActivate("ahk_id " captureGui.Hwnd)
    WinWaitClose("ahk_id " captureGui.Hwnd)
    if ConfiguredPullBuilderState.Count {
        ConfiguredPullBuilderState["workspaceCaptureGuiHwnd"] := 0,
        ConfiguredPullBuilderState["workspaceCaptureApplyFn"] := 0,
        ConfiguredPullBuilderState["workspaceCaptureToggleFn"] := 0
    }
    return state
}
