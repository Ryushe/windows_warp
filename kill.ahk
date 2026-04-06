#Requires AutoHotkey v2.0

global SharedHotkeyRegistryPath := A_ScriptDir "\hotkey_registry.ini"

killHotkey := Kill_GetSharedHotkey("kill.close-active", "#q")
if killHotkey != "" {
    Hotkey(killHotkey, CloseActiveWindow)
}

CloseActiveWindow(*) {
    hwnd := WinExist("A")
    if hwnd {
        WinClose hwnd
    }
}

Kill_GetSharedHotkey(id, fallback := "") {
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
