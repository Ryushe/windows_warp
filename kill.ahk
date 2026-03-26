#Requires AutoHotkey v2.0

#q::
{
    hwnd := WinExist("A")  ; Active window
    if hwnd
    {
        WinClose hwnd
    }
}