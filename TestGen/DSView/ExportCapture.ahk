#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance, Force
SendMode, Input
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
#include %A_ScriptDir%/UIAutomation/Lib/UIA_Interface.ahk

if(A_Args[1] = "" || A_Args[2] = "") {
    MsgBox, "Need arguments for directory and filename"
    ExitApp, -1
}

; Developed for DSView 1.2.2
UIA := UIA_Interface()
WinActivate, ahk_exe DSView.exe
MainWindow := UIA.ElementFromHandle("ahk_exe DSView.exe")

; Find and click the start button
SampleBar := MainWindow.FindFirstByNameAndType("Sampling Bar", 50021)
SampleBar.WaitElementExistByNameAndType("Start", "Button") ; Wait for it to finish capturing
Sleep, 1500

; Find and click the File dropdown button, then activate the Export subitem
FileBar := MainWindow.FindFirstByNameAndType("File Bar", 50021)
FileBtn := FileBar.FindFirstByNameAndType("File", "Button")
FileBtn.SetFocus()
FileBtn.ControlClick()
Sleep, 500

; Can't figure out why this doesn't work
;ExportBtn := MainWindow.FindFirstByNameAndType("'Export...'", 50011)
;ExportBtn.SetFocus()
;ExportBtn.ControlClick()
SendInput {Down}
SendInput {Down}
SendInput {Down}
SendInput {Down}
SendInput {Enter}

; Wait for the export dialog to appear, then set compressed option, and click the file path change button
MainWindow.WaitElementExistByNameAndType("Exporting...", "Text")
;MsgBox, % MainWindow.FindFirstByNameAndType("DSView", 50032).DumpAll()
Dialog := MainWindow.FindFirstByNameAndType("DSView", 50032)
Dialog.FindFirstByNameAndType("Compressed data", 50013).Click()
Dialog.FindFirstByNameAndType("change", 50000).Click()

; Wait for the file browser, then set the correct directory
FileBrowser := MainWindow.WaitElementExistByNameAndType("Export Data", 50032)
PrevLocBtn := FileBrowser.FindFirstByNameAndType("Previous Locations", 50000)
PrevLocBtn.Click()
FileBrowser.FindFirstByNameAndType("Address", 50004).SetValue(A_Args[1])
SendInput {Enter}

; Set the file name and hit save
FileNameBox := Dialog.WaitElementExistByNameAndType("File name:", 50004)
FileNameBox.SetValue(A_Args[2])
FileBrowser.FindFirstByNameAndType("Save", 50000).Click()
Sleep, 500

; If a confirmation appears for file already exists, click yes
ConfirmBox := FileBrowser.WaitElementExistByNameAndType("Confirm Save As", 50032,,,,1000)
ConfirmBox.FindFirstByNameAndType("Yes", 50000).Click()
    
; Wait for the file browser to go away
MainWindow.WaitElementNotExist("Name=Export Data AND Type=50032")

; Click OK back in the DSView export dialog
OKButton := Dialog.WaitElementExistByNameAndType("OK", 50000).Click()
while (IsObject(Dialog.FindFirstByNameAndType("OK", 50000)))
    Sleep, 250
Sleep, 500
ExitApp, 0