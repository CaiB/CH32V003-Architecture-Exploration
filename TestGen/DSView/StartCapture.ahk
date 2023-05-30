#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance, Force
SendMode, Input
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
#include %A_ScriptDir%/UIAutomation/Lib/UIA_Interface.ahk

; Developed for DSView 1.2.2
UIA := UIA_Interface()
WinActivate, ahk_exe DSView.exe
MainWindow := UIA.ElementFromHandle("ahk_exe DSView.exe")

; Find and click the start button
SampleBar := MainWindow.FindFirstByNameAndType("Sampling Bar", 50021)
StartBtn := SampleBar.FindFirstByNameAndType("Start", "Button")
StartBtn.Click()
SampleBar.WaitElementExistByNameAndType("Stop", "Button") ; Wait for capturing to start
Sleep, 500
ExitApp, 0