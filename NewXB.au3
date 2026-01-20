#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=XB_GUI_Profile_Manager.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Description=XB Profile Manager - Device GUI Automation Tool
#AutoIt3Wrapper_Res_Fileversion=1.5.0.0
#AutoIt3Wrapper_Res_LegalCopyright=eXBonez
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Array.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <ColorConstants.au3>
#include <Date.au3>
#include <StringConstants.au3>
#include <Misc.au3>
#include <File.au3>

; Define missing constant
Global Const $CBS_DROPDOWNLIST = 0x3

; Enable OnEvent mode
Opt("GUIOnEventMode", 1)
Opt("MouseCoordMode", 1) ; Screen coordinates
Opt("WinTitleMatchMode", 2)

; ===== GLOBAL VARIABLES =====
Global $scriptDir = @ScriptDir
Global $gamesFile = $scriptDir & "\games.ini"
Global $backupDir = $scriptDir & "\Backups"
Global $profilesDir = $scriptDir & "\Profiles" ; Default profiles subfolder

Global $bgColorCfg = "0x2D2D2D"  ; Dark gray instead of pure black
Global $textColorCfg = "0xE0E0E0" ; Light gray text
Global $sortGamesMode = "Alphabetical"
Global $sortOrder = "Ascending"
Global $defaultProfileDelay = 1000
Global $clickDelayGlobal = 300
Global $lastTab = 1
Global $lastExeDir = $scriptDir ; Start with script directory
Global $trayMinimize = 1
Global $minimizeGuiAfterImport = 0

; Device system
Global $selectedDevice = ""
Global $devices[0]
Global $deviceExtensions[0][0] ; Will be 2D array: [device][extensions]
Global $deviceCurrentExt[0][0] ; Will be 2D array: [device][currentExt]
Global $deviceGuiExe[0][0] ; Will be 2D array: [device][exePath]
Global $deviceClickDelay[0][0] ; Will be 2D array: [device][delay]
Global $deviceProfileDir[0][0] ; Will be 2D array: [device][dir]

Global $currentProfileExtension = "*"

; Games data - Using arrays to store game information
Global $games[0][9] ; Columns: Name, Exe, Profile, PostImportDelay, LaunchExe, CloseManager, Added, LastPlayed, LaunchCount
Global $gameNames[0] ; Just the game names for easy access
Global $gameProfiles[0][0] ; 2D array for device-specific profiles [gameIndex][deviceIndex]

Global $profiles[0][2] ; Profile data: [Name, Notes]
Global $fullGameNames[0]
Global $fullProfileNames[0]
Global $current_notes_game = ""
Global $current_notes_profile = ""

; Import automation variables
Global $clickCaptureCount = 0
Global $clickCapturedList[0][2] ; Array of [x, y] coordinates
Global $overlayGui = 0
Global $clickCounterText = 0
Global $f8HotkeyRegistered = False

; GUI Controls
Global $mainGui, $titleBar, $hMin, $hClose, $hTabs[4], $hLine, $iActive = 0
Global $tabContent[4][100], $tabControlCount[4] = [0, 0, 0, 0]

; Tab 1: Game Launcher controls
Global $launcherDeviceDrop, $launcherSearchEdit, $lbLauncher, $launcherSelLabel
Global $launcherNotesEdit, $launchBtn, $launcherOpenFolderBtn, $launcherLaunchEditorBtn

; Tab 2: Profile Manager controls
Global $profilesDeviceDrop, $profilesSearchEdit, $lbProfiles, $profileSelLabel
Global $profilesNotesEdit, $profilesImportBtn, $profilesOpenFolderBtn
Global $profilesBackupBtn, $profilesSetFolderBtn, $profilesLaunchEditorBtn

; Tab 3: Game Editor controls
Global $editorDeviceDrop, $editorSearchEdit, $lbGames, $selGameLabel
Global $editorAddBtn, $editorRemoveBtn, $editorCreateShortcutBtn, $editorClearBtn
Global $editorOpenFolderBtn, $gameExeEdit, $editorBrowseExeBtn, $editorOpenExeFolderBtn
Global $gameNameEdit, $gameProfileEdit, $editorBrowseProfileBtn, $gameDelayEdit
Global $launchExeCheckbox, $closeManagerCheckbox, $guiCloseDelayEdit

; Tab 4: Settings controls
Global $settingsDeviceBox, $gamesSortDrop, $orderSortDrop
Global $launchEditorBtn, $captureImportBtn, $openProfilesBtn, $testImportBtn
Global $selectDeviceGuiExeBtn, $openProfileFolderBtn, $clickDelayEdit, $saveDelayBtn
Global $minimizeGuiCheckbox, $selectDeviceProfileDirBtn, $devicesDrop
Global $addDeviceBtn, $deleteDeviceBtn, $profileExtDrop, $addExtEdit, $addExtBtn
Global $bgColorBtn, $textColorPreview

; ===== UTILITY FUNCTIONS =====
Func _CurrentIsoTimestamp()
    Return _NowCalc()
EndFunc

Func _GetBaseGameName($displayName)
    ; Remove device suffix in parentheses
    If StringInStr($displayName, "(") Then
        Return StringStripWS(StringLeft($displayName, StringInStr($displayName, "(") - 1), 3)
    EndIf
    Return $displayName
EndFunc

Func _GetDeviceClickDelay($deviceName)
    For $i = 0 To UBound($deviceClickDelay) - 1
        If $deviceClickDelay[$i][0] = $deviceName Then
            Return $deviceClickDelay[$i][1]
        EndIf
    Next
    Return $clickDelayGlobal
EndFunc

Func _GetDeviceProfileDir($deviceName)
    For $i = 0 To UBound($deviceProfileDir) - 1
        If $deviceProfileDir[$i][0] = $deviceName Then
            Return $deviceProfileDir[$i][1]
        EndIf
    Next
    Return $profilesDir ; Use profiles subfolder instead of @MyDocumentsDir
EndFunc

Func _DeviceExists($name)
    For $dev In $devices
        If $dev = $name Then Return True
    Next
    Return False
EndFunc

Func _AddToTab($tabIndex, $ctrlID)
    $tabContent[$tabIndex][$tabControlCount[$tabIndex]] = $ctrlID
    $tabControlCount[$tabIndex] += 1
EndFunc

Func _EnsureDefaultFolders()
    ; Create necessary subfolders if they don't exist
    If Not FileExists($backupDir) Then DirCreate($backupDir)
    If Not FileExists($profilesDir) Then DirCreate($profilesDir)
EndFunc

Func _FixControlColors()
    ; Simple color fix for better readability
    ; Set background for listboxes
    GUICtrlSetBkColor($lbLauncher, 0x1E1E1E)
    GUICtrlSetColor($lbLauncher, 0xE0E0E0)
    
    GUICtrlSetBkColor($lbProfiles, 0x1E1E1E)
    GUICtrlSetColor($lbProfiles, 0xE0E0E0)
    
    GUICtrlSetBkColor($lbGames, 0x1E1E1E)
    GUICtrlSetColor($lbGames, 0xE0E0E0)
    
    ; Set background for edit controls
    GUICtrlSetBkColor($launcherNotesEdit, 0x1E1E1E)
    GUICtrlSetColor($launcherNotesEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($profilesNotesEdit, 0x1E1E1E)
    GUICtrlSetColor($profilesNotesEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($gameExeEdit, 0x1E1E1E)
    GUICtrlSetColor($gameExeEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($gameNameEdit, 0x1E1E1E)
    GUICtrlSetColor($gameNameEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($gameProfileEdit, 0x1E1E1E)
    GUICtrlSetColor($gameProfileEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($gameDelayEdit, 0x1E1E1E)
    GUICtrlSetColor($gameDelayEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($guiCloseDelayEdit, 0x1E1E1E)
    GUICtrlSetColor($guiCloseDelayEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($clickDelayEdit, 0x1E1E1E)
    GUICtrlSetColor($clickDelayEdit, 0xE0E0E0)
    
    GUICtrlSetBkColor($addExtEdit, 0x1E1E1E)
    GUICtrlSetColor($addExtEdit, 0xE0E0E0)
    
    ; Set background for combo boxes
    GUICtrlSetBkColor($launcherDeviceDrop, 0x1E1E1E)
    GUICtrlSetColor($launcherDeviceDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($profilesDeviceDrop, 0x1E1E1E)
    GUICtrlSetColor($profilesDeviceDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($editorDeviceDrop, 0x1E1E1E)
    GUICtrlSetColor($editorDeviceDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($gamesSortDrop, 0x1E1E1E)
    GUICtrlSetColor($gamesSortDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($orderSortDrop, 0x1E1E1E)
    GUICtrlSetColor($orderSortDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($devicesDrop, 0x1E1E1E)
    GUICtrlSetColor($devicesDrop, 0xE0E0E0)
    
    GUICtrlSetBkColor($profileExtDrop, 0x1E1E1E)
    GUICtrlSetColor($profileExtDrop, 0xE0E0E0)
    
    ; Set text colors for labels (keep them light gray)
    GUICtrlSetColor($launcherSelLabel, 0xE0E0E0)
    GUICtrlSetColor($profileSelLabel, 0xE0E0E0)
    GUICtrlSetColor($selGameLabel, 0xE0E0E0)
EndFunc

; ===== INI FILE SYSTEM FUNCTIONS =====
Func _EnsureDefaultIniKeys()
    ; Ensure all required INI keys exist
    Local $requiredKeys[6][2] = [ _
        ["SelectedDevice", "Default"], _
        ["SelectedExtension", "*"], _
        ["DefaultProfileDelay", "1000"], _
        ["ClickDelay", "300"], _
        ["ProfilesDir", $profilesDir], _
        ["LastTab", "1"] _
    ]
    
    For $i = 0 To UBound($requiredKeys) - 1
        Local $currentValue = IniRead($gamesFile, "Config", $requiredKeys[$i][0], "")
        If $currentValue = "" Then
            IniWrite($gamesFile, "Config", $requiredKeys[$i][0], $requiredKeys[$i][1])
        EndIf
    Next
EndFunc

Func _LoadConfig()
    ; Load global configuration from INI
    $bgColorCfg = IniRead($gamesFile, "Theme", "BgColor", "0x2D2D2D")
    $textColorCfg = IniRead($gamesFile, "Theme", "TextColor", "0xE0E0E0")
    $sortGamesMode = IniRead($gamesFile, "Sort", "Games", "Alphabetical")
    $sortOrder = IniRead($gamesFile, "Sort", "Order", "Ascending")
    $defaultProfileDelay = Int(IniRead($gamesFile, "Config", "DefaultProfileDelay", "1000"))
    $clickDelayGlobal = Int(IniRead($gamesFile, "Config", "ClickDelay", "300"))
    $profilesDir = IniRead($gamesFile, "Config", "ProfilesDir", $scriptDir & "\Profiles")
    $lastTab = Int(IniRead($gamesFile, "Config", "LastTab", "1"))
    $lastExeDir = IniRead($gamesFile, "Config", "LastExeDir", $scriptDir)
    $trayMinimize = Int(IniRead($gamesFile, "Config", "TrayMinimize", "1"))
    $minimizeGuiAfterImport = Int(IniRead($gamesFile, "Config", "MinimizeGuiAfterImport", "0"))
    
    If $lastTab < 1 Or $lastTab > 4 Then
        $lastTab = 1
    EndIf
EndFunc

Func _LoadDevices()
    ; Load devices from INI
    Local $rawDevices, $deviceLine, $deviceParts, $tempDevName, $i = 0
    
    ; Clear arrays
    ReDim $devices[0]
    ReDim $deviceGuiExe[0][2]
    ReDim $deviceClickDelay[0][2]
    ReDim $deviceProfileDir[0][2]
    
    If Not FileExists($gamesFile) Then Return
    
    ; Load device names from [Devices] section
    Local $deviceSection = IniReadSection($gamesFile, "Devices")
    If Not @error Then
        For $i = 1 To $deviceSection[0][0]
            $tempDevName = StringStripWS($deviceSection[$i][1], 3)
            If $tempDevName <> "" Then
                _ArrayAdd($devices, $tempDevName)
            EndIf
        Next
    EndIf
    
    ; If no devices found, add "Default"
    If UBound($devices) = 0 Then
        _ArrayAdd($devices, "Default")
        IniWrite($gamesFile, "Devices", "1", "Default")
    EndIf
    
    ; Set selected device if not set or doesn't exist
    If $selectedDevice = "" Or Not _DeviceExists($selectedDevice) Then
        $selectedDevice = $devices[0]
        IniWrite($gamesFile, "Config", "SelectedDevice", $selectedDevice)
    EndIf
    
    ; Load device-specific settings
    For $dName In $devices
        Local $exePath = IniRead($gamesFile, "Device_" & $dName, "DeviceGuiExe", "")
        If $exePath <> "" Then
            Local $size = UBound($deviceGuiExe)
            ReDim $deviceGuiExe[$size + 1][2]
            $deviceGuiExe[$size][0] = $dName
            $deviceGuiExe[$size][1] = $exePath
        EndIf
        
        Local $delay = IniRead($gamesFile, "Device_" & $dName, "ClickDelay", "")
        If $delay <> "" And StringRegExp($delay, "^\d+$") Then
            Local $size = UBound($deviceClickDelay)
            ReDim $deviceClickDelay[$size + 1][2]
            $deviceClickDelay[$size][0] = $dName
            $deviceClickDelay[$size][1] = Int($delay)
        EndIf
        
        Local $dir = IniRead($gamesFile, "Device_" & $dName, "ProfileDir", "")
        If $dir <> "" And DirExists($dir) Then
            Local $size = UBound($deviceProfileDir)
            ReDim $deviceProfileDir[$size + 1][2]
            $deviceProfileDir[$size][0] = $dName
            $deviceProfileDir[$size][1] = $dir
        EndIf
    Next
EndFunc

Func _LoadDeviceExtensions()
    ; Load device extensions from INI
    ReDim $deviceExtensions[0][0]
    ReDim $deviceCurrentExt[0][0]
    
    If Not FileExists($gamesFile) Then Return
    
    ; Load device extensions
    Local $extSection = IniReadSection($gamesFile, "DeviceExtensions")
    If Not @error Then
        For $i = 1 To $extSection[0][0]
            Local $tempDev = $extSection[$i][0]
            Local $extStr = $extSection[$i][1]
            Local $extArr = StringSplit($extStr, ",", 2)
            
            ; Add to deviceExtensions array
            Local $size = UBound($deviceExtensions)
            ReDim $deviceExtensions[$size + 1][2]
            $deviceExtensions[$size][0] = $tempDev
            $deviceExtensions[$size][1] = $extArr
        Next
    EndIf
    
    ; Load current extensions
    Local $curExtSection = IniReadSection($gamesFile, "DeviceCurrentExt")
    If Not @error Then
        For $i = 1 To $curExtSection[0][0]
            Local $tempDev = $curExtSection[$i][0]
            Local $curExt = $curExtSection[$i][1]
            
            Local $size = UBound($deviceCurrentExt)
            ReDim $deviceCurrentExt[$size + 1][2]
            $deviceCurrentExt[$size][0] = $tempDev
            $deviceCurrentExt[$size][1] = $curExt
        Next
    EndIf
    
    ; Ensure all devices have extension settings
    For $tempDev In $devices
        Local $foundExt = False
        For $i = 0 To UBound($deviceExtensions) - 1
            If $deviceExtensions[$i][0] = $tempDev Then
                $foundExt = True
                ExitLoop
            EndIf
        Next
        
        If Not $foundExt Then
            ; Add empty extensions array for this device
            Local $size = UBound($deviceExtensions)
            ReDim $deviceExtensions[$size + 1][2]
            $deviceExtensions[$size][0] = $tempDev
            $deviceExtensions[$size][1] = StringSplit("", ",", 2) ; Empty array
        EndIf
        
        Local $foundCurExt = False
        For $i = 0 To UBound($deviceCurrentExt) - 1
            If $deviceCurrentExt[$i][0] = $tempDev Then
                $foundCurExt = True
                ExitLoop
            EndIf
        Next
        
        If Not $foundCurExt Then
            ; Set default current extension
            Local $size = UBound($deviceCurrentExt)
            ReDim $deviceCurrentExt[$size + 1][2]
            $deviceCurrentExt[$size][0] = $tempDev
            $deviceCurrentExt[$size][1] = "*"
            IniWrite($gamesFile, "DeviceCurrentExt", $tempDev, "*")
        EndIf
    Next
    
    ; Set current profile extension for selected device
    If $selectedDevice <> "" Then
        For $i = 0 To UBound($deviceCurrentExt) - 1
            If $deviceCurrentExt[$i][0] = $selectedDevice Then
                $currentProfileExtension = $deviceCurrentExt[$i][1]
                ExitLoop
            EndIf
        Next
    Else
        $currentProfileExtension = "*"
    EndIf
EndFunc

Func _SaveDeviceExtensionsToIni()
    ; Save device extensions to INI
    IniDelete($gamesFile, "DeviceExtensions")
    For $i = 0 To UBound($deviceExtensions) - 1
        Local $tempDev = $deviceExtensions[$i][0]
        Local $extArr = $deviceExtensions[$i][1]
        Local $extStr = _ArrayToString($extArr, ",")
        IniWrite($gamesFile, "DeviceExtensions", $tempDev, $extStr)
    Next
    
    IniDelete($gamesFile, "DeviceCurrentExt")
    For $i = 0 To UBound($deviceCurrentExt) - 1
        Local $tempDev = $deviceCurrentExt[$i][0]
        Local $curExt = $deviceCurrentExt[$i][1]
        IniWrite($gamesFile, "DeviceCurrentExt", $tempDev, $curExt)
    Next
EndFunc

Func _LoadGames()
    ; Load games from INI
    ReDim $games[0][9] ; Clear games array
    ReDim $gameNames[0]
    
    If Not FileExists($gamesFile) Then Return
    
    Local $gameSection = IniReadSection($gamesFile, "Games")
    If @error Then Return
    
    ; Temporary map to collect game data
    Local $gameMap = ObjCreate("Scripting.Dictionary")
    
    For $i = 1 To $gameSection[0][0]
        Local $key = $gameSection[$i][0]
        Local $value = $gameSection[$i][1]
        
        If Not StringInStr($key, ".") Then ContinueLoop
        
        Local $parts = StringSplit($key, ".")
        If $parts[0] < 2 Then ContinueLoop
        
        Local $gameKey = StringRegExpReplace($parts[1], "\s", "")
        Local $field = $parts[2]
        
        ; Handle old format: GameNameDevice.Profiles
        If $field = "Profiles" Then
            ; Find which device this belongs to
            For $dev In $devices
                If $dev <> "Default" And StringRight($gameKey, StringLen($dev)) = $dev Then
                    Local $baseGameKey = StringLeft($gameKey, StringLen($gameKey) - StringLen($dev))
                    Local $newKey = $baseGameKey & ".Profile" & $dev
                    IniWrite($gamesFile, "Games", $newKey, $value)
                    $gameKey = $baseGameKey
                    $field = "Profile_" & $dev
                    ExitLoop
                EndIf
            Next
        ElseIf StringLeft($field, 7) = "Profile" Then
            ; New format: GameName.ProfileDevice
            Local $devName = StringMid($field, 8)
            $field = "Profile_" & $devName
        EndIf
        
        ; Create game entry if it doesn't exist
        If Not $gameMap.Exists($gameKey) Then
            $gameMap.Add($gameKey, "")
            ; Initialize with default values
            Local $newSize = UBound($games)
            ReDim $games[$newSize + 1][9]
            $games[$newSize][0] = $gameKey ; Name
            $games[$newSize][1] = "" ; Exe
            $games[$newSize][2] = "" ; Profile (for current device)
            $games[$newSize][3] = 1500 ; PostImportDelay
            $games[$newSize][4] = 1 ; LaunchExe
            $games[$newSize][5] = 1 ; CloseManager
            $games[$newSize][6] = "" ; Added
            $games[$newSize][7] = "" ; LastPlayed
            $games[$newSize][8] = 0 ; LaunchCount
            
            _ArrayAdd($gameNames, $gameKey)
        EndIf
        
        ; Find the game index
        Local $gameIndex = -1
        For $j = 0 To UBound($gameNames) - 1
            If $gameNames[$j] = $gameKey Then
                $gameIndex = $j
                ExitLoop
            EndIf
        Next
        
        If $gameIndex = -1 Then ContinueLoop
        
        ; Set the field value
        Switch $field
            Case "Exe"
                $games[$gameIndex][1] = $value
            Case "PostImportDelay"
                $games[$gameIndex][3] = Int($value)
            Case "LaunchExe"
                $games[$gameIndex][4] = Int($value)
            Case "CloseManager"
                $games[$gameIndex][5] = Int($value)
            Case "Added"
                $games[$gameIndex][6] = $value
            Case "LastPlayed"
                $games[$gameIndex][7] = $value
            Case "LaunchCount"
                $games[$gameIndex][8] = Int($value)
            Case StringLeft($field, 8) = "Profile_"
                ; This is device-specific profile - we'll handle this separately
                ; For now, if it's for the current device, store it
                Local $devName = StringMid($field, 9)
                If $devName = $selectedDevice Then
                    $games[$gameIndex][2] = $value
                EndIf
        EndSwitch
    Next
EndFunc

Func _LoadProfiles()
    ; Load profile notes from INI
    ReDim $profiles[0][2]
    
    If Not FileExists($gamesFile) Then Return
    
    Local $profileSection = IniReadSection($gamesFile, "Profiles")
    If @error Then Return
    
    For $i = 1 To $profileSection[0][0]
        Local $key = $profileSection[$i][0]
        Local $value = $profileSection[$i][1]
        
        If Not StringInStr($key, ".") Then ContinueLoop
        
        Local $parts = StringSplit($key, ".")
        If $parts[0] < 2 Then ContinueLoop
        
        Local $profileName = $parts[1]
        Local $field = $parts[2]
        
        If $field = "Notes" Then
            Local $size = UBound($profiles)
            ReDim $profiles[$size + 1][2]
            $profiles[$size][0] = $profileName
            $profiles[$size][1] = $value
        EndIf
    Next
EndFunc

Func _SaveGameToIni($gameName, $exe, $profile, $delay, $launch, $added, $lastPlayed, $launchCount, $closeManager)
    ; Save game data to INI
    Local $key = StringRegExpReplace($gameName, "\s", "")
    
    IniWrite($gamesFile, "Games", $key & ".Exe", $exe)
    
    If $selectedDevice <> "" And $profile <> "" Then
        Local $deviceProfileKey = $key & ".Profile" & $selectedDevice
        IniWrite($gamesFile, "Games", $deviceProfileKey, $profile)
        
        ; Delete old format key if it exists
        Local $oldKey = $key & $selectedDevice & ".Profiles"
        IniDelete($gamesFile, "Games", $oldKey)
    EndIf
    
    IniWrite($gamesFile, "Games", $key & ".PostImportDelay", $delay)
    IniWrite($gamesFile, "Games", $key & ".LaunchExe", $launch)
    IniWrite($gamesFile, "Games", $key & ".CloseManager", $closeManager)
    
    If $added <> "" Then
        IniWrite($gamesFile, "Games", $key & ".Added", $added)
    EndIf
    
    If $lastPlayed <> "" Then
        IniWrite($gamesFile, "Games", $key & ".LastPlayed", $lastPlayed)
    EndIf
    
    If $launchCount <> "" Then
        IniWrite($gamesFile, "Games", $key & ".LaunchCount", $launchCount)
    EndIf
EndFunc

Func _RemoveGameFromIni($gameName)
    ; Remove game from INI
    Local $key = StringRegExpReplace($gameName, "\s", "")
    
    ; Remove standard fields
    Local $fields[7] = ["Exe", "Profiles", "PostImportDelay", "LaunchExe", "Added", "LastPlayed", "LaunchCount"]
    For $field In $fields
        IniDelete($gamesFile, "Games", $key & "." & $field)
    Next
    
    ; Remove device-specific profile fields
    For $dev In $devices
        Local $deviceProfileKey = $key & ".Profile" & $dev
        IniDelete($gamesFile, "Games", $deviceProfileKey)
        
        Local $oldKey = $key & $dev & ".Profiles"
        IniDelete($gamesFile, "Games", $oldKey)
    Next
    
    ; Remove GUI close delay
    IniDelete($gamesFile, "Games", $gameName & ".GuiCloseDelay")
EndFunc

Func _GetGamesForCurrentDevice()
    ; Get games that have profiles for the current device
    Local $filteredGames[0][9]
    Local $filteredNames[0]
    
    For $i = 0 To UBound($games) - 1
        Local $gameName = $games[$i][0]
        Local $hasProfile = False
        
        ; Check if this game has a profile for current device
        Local $key = StringRegExpReplace($gameName, "\s", "")
        Local $deviceProfileKey = $key & ".Profile" & $selectedDevice
        Local $profile = IniRead($gamesFile, "Games", $deviceProfileKey, "")
        
        If $profile = "" Then
            ; Check old format
            Local $oldKey = $key & $selectedDevice & ".Profiles"
            $profile = IniRead($gamesFile, "Games", $oldKey, "")
            
            If $profile <> "" Then
                ; Convert to new format
                IniWrite($gamesFile, "Games", $deviceProfileKey, $profile)
                $hasProfile = True
            EndIf
        Else
            $hasProfile = True
        EndIf
        
        If $hasProfile Then
            Local $size = UBound($filteredGames)
            ReDim $filteredGames[$size + 1][9]
            
            ; Copy game data
            For $j = 0 To 8
                $filteredGames[$size][$j] = $games[$i][$j]
            Next
            
            ; Update profile path for current device
            $filteredGames[$size][2] = $profile
            
            _ArrayAdd($filteredNames, $gameName)
        EndIf
    Next
    
    Return $filteredNames
EndFunc

Func _GetGameProfileForDevice($gameName, $deviceName)
    ; Get profile path for a specific game and device
    If $deviceName = "" Then Return ""
    
    Local $key = StringRegExpReplace($gameName, "\s", "")
    Local $deviceProfile = IniRead($gamesFile, "Games", $key & ".Profile" & $deviceName, "")
    
    If $deviceProfile = "" Then
        ; Check old format
        Local $oldKey = $key & $deviceName & ".Profiles"
        $deviceProfile = IniRead($gamesFile, "Games", $oldKey, "")
        
        If $deviceProfile <> "" Then
            ; Convert to new format
            Local $newKey = $key & ".Profile" & $deviceName
            IniWrite($gamesFile, "Games", $newKey, $deviceProfile)
        EndIf
    EndIf
    
    Return $deviceProfile
EndFunc

Func _RepairGamesIni()
    ; Repair old INI format
    If Not FileExists($gamesFile) Then Return
    
    Local $gameSection = IniReadSection($gamesFile, "Games")
    If @error Then Return
    
    Local $fixed = False
    
    For $i = 1 To $gameSection[0][0]
        Local $key = $gameSection[$i][0]
        Local $value = $gameSection[$i][1]
        
        ; Look for old format: Game.ProfileDevice (missing dot)
        If StringInStr($key, ".Profile") And Not StringInStr($key, ".Profile.") Then
            ; This is the new format, not old
            ContinueLoop
        EndIf
        
        ; Look for really old format or other issues
        ; For now, we'll just reload everything which should fix most issues
    Next
    
    If $fixed Then
        _LoadGames()
    EndIf
EndFunc

; ===== IMPORT AUTOMATION FUNCTIONS =====
Func _CaptureImportButtonCoords()
    ; Click count dialog
    Local $countGui = GUICreate("Click Count", 250, 150, -1, -1, BitOR($WS_POPUP, $WS_BORDER, $WS_EX_TOOLWINDOW))
    GUISetFont(11, 400, 0, "Segoe UI")
    GUISetBkColor(0x2D2D2D, $countGui)
    
    Local $label = GUICtrlCreateLabel("How many clicks to record?", 20, 20, 210, 25)
    GUICtrlSetColor($label, 0xE0E0E0)
    
    Local $dd = GUICtrlCreateCombo("", 20, 50, 210, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($dd, "1|2|3|4|5|6|7|8|9|10", "1")
    GUICtrlSetBkColor($dd, 0x1E1E1E)
    GUICtrlSetColor($dd, 0xE0E0E0)
    
    Local $okBtn = GUICtrlCreateButton("OK", 20, 90, 210, 30)
    GUICtrlSetBkColor($okBtn, 0x3B82F6)
    GUICtrlSetColor($okBtn, 0xFFFFFF)
    
    GUISetState(@SW_SHOW, $countGui)
    
    Local $msg
    While 1
        $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                GUIDelete($countGui)
                Return
            Case $okBtn
                $clickCaptureCount = Int(GUICtrlRead($dd))
                ReDim $clickCapturedList[0][2]
                GUIDelete($countGui)
                _StartClickCaptureOverlay()
                Return
        EndSwitch
        Sleep(10)
    WEnd
EndFunc

Func _StartClickCaptureOverlay()
    ; Get device GUI EXE for current device
    Local $currentDeviceGuiExe = ""
    For $i = 0 To UBound($deviceGuiExe) - 1
        If $deviceGuiExe[$i][0] = $selectedDevice Then
            $currentDeviceGuiExe = $deviceGuiExe[$i][1]
            ExitLoop
        EndIf
    Next
    
    If $currentDeviceGuiExe = "" Or Not FileExists($currentDeviceGuiExe) Then
        MsgBox($MB_ICONWARNING, "Error", "Device GUI EXE is not set or missing for device: " & $selectedDevice)
        Return
    EndIf
    
    ; Extract process name
    Local $processName = StringRegExpReplace($currentDeviceGuiExe, ".*\\", "")
    
    ; Launch device GUI if not running
    If Not ProcessExists($processName) Then
        Run($currentDeviceGuiExe)
        Sleep(1500)
    EndIf
    
    ; Try to activate window
    Local $activated = False
    Local $winList = WinList("[CLASS:#32770]")
    For $i = 1 To $winList[0][0]
        If $winList[$i][0] <> "" Then
            WinActivate($winList[$i][1])
            $activated = True
            ExitLoop
        EndIf
    Next
    
    If Not $activated Then
        $winList = WinList("[TITLE:*Device*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    If Not $activated Then
        $winList = WinList("[TITLE:*GUI*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    If Not $activated Then
        MsgBox($MB_ICONWARNING, "Error", "Could not find Device GUI window.")
        Return
    EndIf
    
    Sleep(300)
    
    ; Create overlay GUI
    $overlayGui = GUICreate("Click Capture Overlay", 360, 130, -1, -1, _
        BitOR($WS_POPUP, $WS_BORDER, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), -1, $mainGui)
    GUISetBkColor(0xEEAA99, $overlayGui)
    WinSetTrans($overlayGui, "", 200)
    GUISetFont(11, 400, 0, "Segoe UI")
    
    Local $label1 = GUICtrlCreateLabel("Click Counter:", 20, 15, 320, 20, $SS_CENTER)
    GUICtrlSetColor($label1, 0x000000)
    
    $clickCounterText = GUICtrlCreateLabel($clickCaptureCount & " clicks left", 20, 40, 320, 30, $SS_CENTER)
    GUICtrlSetFont($clickCounterText, 11, 700)
    GUICtrlSetColor($clickCounterText, 0x000000)
    
    Local $currentClickDelay = _GetDeviceClickDelay($selectedDevice)
    Local $label2 = GUICtrlCreateLabel("Delay between clicks: " & $currentClickDelay & "ms", 20, 75, 320, 20, $SS_CENTER)
    GUICtrlSetColor($label2, 0x000000)
    
    Local $label3 = GUICtrlCreateLabel("Press F8 to capture each click", 20, 95, 320, 20, $SS_CENTER)
    GUICtrlSetColor($label3, 0x000000)
    
    GUISetState(@SW_SHOW, $overlayGui)
    
    ; Register F8 hotkey
    HotKeySet("{F8}", "_MultiClickCapture_Fire")
    $f8HotkeyRegistered = True
    
    ; Center overlay
    Local $mainPos = WinGetPos($mainGui)
    Local $overlayPos = WinGetPos($overlayGui)
    If Not @error Then
        WinMove($overlayGui, "", _
            $mainPos[0] + ($mainPos[2] - $overlayPos[2]) / 2, _
            $mainPos[1] + ($mainPos[3] - $overlayPos[3]) / 2)
    EndIf
EndFunc

Func _MultiClickCapture_Fire()
    ; Get current mouse position
    Local $pos = MouseGetPos()
    Local $x = $pos[0]
    Local $y = $pos[1]
    
    ; Add to captured list
    Local $size = UBound($clickCapturedList)
    ReDim $clickCapturedList[$size + 1][2]
    $clickCapturedList[$size][0] = $x
    $clickCapturedList[$size][1] = $y
    
    Local $clicksLeft = $clickCaptureCount - ($size + 1)
    
    If $clicksLeft > 0 Then
        ; Update counter
        GUICtrlSetData($clickCounterText, $clicksLeft & " click" & ($clicksLeft = 1 ? "" : "s") & " left")
        Return
    EndIf
    
    ; All clicks captured
    HotKeySet("{F8}") ; Unregister hotkey
    $f8HotkeyRegistered = False
    
    ; Save to INI
    IniWrite($gamesFile, "Device_" & $selectedDevice, "ImportClickCount", $clickCaptureCount)
    
    For $i = 0 To UBound($clickCapturedList) - 1
        IniWrite($gamesFile, "Device_" & $selectedDevice, "ImportButtonX" & ($i + 1), $clickCapturedList[$i][0])
        IniWrite($gamesFile, "Device_" & $selectedDevice, "ImportButtonY" & ($i + 1), $clickCapturedList[$i][1])
    Next
    
    ; Also save first click as default
    If UBound($clickCapturedList) >= 1 Then
        IniWrite($gamesFile, "Device_" & $selectedDevice, "ImportButtonX", $clickCapturedList[0][0])
        IniWrite($gamesFile, "Device_" & $selectedDevice, "ImportButtonY", $clickCapturedList[0][1])
    EndIf
    
    ; Close overlay
    GUIDelete($overlayGui)
    $overlayGui = 0
    
    ; Show success message
    Local $currentClickDelay = _GetDeviceClickDelay($selectedDevice)
    
    Local $successGui = GUICreate("Success", 360, 140, -1, -1, _
        BitOR($WS_POPUP, $WS_BORDER, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), -1, $mainGui)
    GUISetBkColor(0x90EE90, $successGui)
    WinSetTrans($successGui, "", 220)
    GUISetFont(11, 700, 0, "Segoe UI")
    
    Local $label1 = GUICtrlCreateLabel("✓ Recording Success!", 20, 15, 320, 40, $SS_CENTER)
    GUICtrlSetColor($label1, 0x006400)
    
    Local $label2 = GUICtrlCreateLabel("Saved " & $clickCaptureCount & " click(s)", 20, 60, 320, 30, $SS_CENTER)
    GUICtrlSetColor($label2, 0x000000)
    
    Local $label3 = GUICtrlCreateLabel("Click delay: " & $currentClickDelay & "ms", 20, 90, 320, 30, $SS_CENTER)
    GUICtrlSetColor($label3, 0x000000)
    
    GUISetState(@SW_SHOW, $successGui)
    
    ; Center success message
    Local $mainPos = WinGetPos($mainGui)
    Local $successPos = WinGetPos($successGui)
    If Not @error Then
        WinMove($successGui, "", _
            $mainPos[0] + ($mainPos[2] - $successPos[2]) / 2, _
            $mainPos[1] + ($mainPos[3] - $successPos[3]) / 2)
    EndIf
    
    Sleep(3000)
    GUIDelete($successGui)
    
    ; Close device GUI
    Local $currentDeviceGuiExe = ""
    For $i = 0 To UBound($deviceGuiExe) - 1
        If $deviceGuiExe[$i][0] = $selectedDevice Then
            $currentDeviceGuiExe = $deviceGuiExe[$i][1]
            ExitLoop
        EndIf
    Next
    
    If $currentDeviceGuiExe <> "" Then
        Local $processName = StringRegExpReplace($currentDeviceGuiExe, ".*\\", "")
        If ProcessExists($processName) Then
            ProcessClose($processName)
        EndIf
    EndIf
EndFunc

Func _TestImportClick()
    ; Test captured import clicks
    Local $currentDeviceGuiExe = ""
    For $i = 0 To UBound($deviceGuiExe) - 1
        If $deviceGuiExe[$i][0] = $selectedDevice Then
            $currentDeviceGuiExe = $deviceGuiExe[$i][1]
            ExitLoop
        EndIf
    Next
    
    If $currentDeviceGuiExe = "" Or Not FileExists($currentDeviceGuiExe) Then
        MsgBox($MB_ICONWARNING, "Error", "Device GUI EXE is not set or missing for device: " & $selectedDevice)
        Return
    EndIf
    
    ; Check for captured clicks
    Local $clickCount = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportClickCount", 0)
    If $clickCount = 0 Then
        MsgBox($MB_ICONWARNING, "No Clicks Found", "No captured clicks found for device: " & $selectedDevice & @CRLF & _
            "Run 'Capture Import Button' first.", 5)
        Return
    EndIf
    
    ; Load click coordinates
    Local $clickList[0][2]
    For $i = 1 To $clickCount
        Local $x = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonX" & $i, "")
        Local $y = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonY" & $i, "")
        If $x = "" Or $y = "" Then ExitLoop
        
        Local $size = UBound($clickList)
        ReDim $clickList[$size + 1][2]
        $clickList[$size][0] = $x
        $clickList[$size][1] = $y
    Next
    
    If UBound($clickList) = 0 Then
        MsgBox($MB_ICONWARNING, "Error", "No valid click coordinates found for device: " & $selectedDevice)
        Return
    EndIf
    
    ; Launch device GUI
    Local $processName = StringRegExpReplace($currentDeviceGuiExe, ".*\\", "")
    Run($currentDeviceGuiExe)
    Sleep(1000)
    
    ; Try to activate window
    Local $activated = False
    Local $winList = WinList("[CLASS:#32770]")
    For $i = 1 To $winList[0][0]
        If $winList[$i][0] <> "" Then
            WinActivate($winList[$i][1])
            $activated = True
            ExitLoop
        EndIf
    Next
    
    If Not $activated Then
        $winList = WinList("[TITLE:*Device*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    If Not $activated Then
        $winList = WinList("[TITLE:*GUI*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    If Not $activated Then
        MsgBox($MB_ICONWARNING, "Error", "Could not find Device GUI window.")
        Return
    EndIf
    
    Sleep(300)
    
    ; Get current click delay
    Local $currentClickDelay = _GetDeviceClickDelay($selectedDevice)
    
    ; Perform clicks
    For $i = 0 To UBound($clickList) - 1
        MouseMove($clickList[$i][0], $clickList[$i][1], 10)
        Sleep(200)
        MouseClick("left")
        
        If $i < UBound($clickList) - 1 Then
            Sleep($currentClickDelay)
        EndIf
    Next
    
    Sleep(1000)
    
    ; Close device GUI
    If ProcessExists($processName) Then
        ProcessClose($processName)
    EndIf
    
    MsgBox($MB_ICONINFORMATION, "Success", "Test click sequence completed successfully.")
EndFunc

Func _ImportProfile($profilePath, $customDelay = "")
    ; Import a profile file
    Local $currentDeviceGuiExe = ""
    For $i = 0 To UBound($deviceGuiExe) - 1
        If $deviceGuiExe[$i][0] = $selectedDevice Then
            $currentDeviceGuiExe = $deviceGuiExe[$i][1]
            ExitLoop
        EndIf
    Next
    
    If $currentDeviceGuiExe = "" Then
        MsgBox($MB_ICONERROR, "Error", "Device GUI EXE is not set for device: " & $selectedDevice & @CRLF & _
            "Please select it in Settings.", 5)
        Return
    EndIf
    
    If Not FileExists($currentDeviceGuiExe) Then
        MsgBox($MB_ICONERROR, "Error", "Device GUI software not found at:" & @CRLF & $currentDeviceGuiExe, 5)
        Return
    EndIf
    
    If Not FileExists($profilePath) Then
        MsgBox($MB_ICONERROR, "Error", "Profile file not found:" & @CRLF & $profilePath)
        Return
    EndIf
    
    ; Load click coordinates
    Local $clickCount = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportClickCount", 0)
    Local $clickList[0][2]
    
    If $clickCount > 0 Then
        For $i = 1 To $clickCount
            Local $x = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonX" & $i, "")
            Local $y = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonY" & $i, "")
            If $x = "" Or $y = "" Then ExitLoop
            
            Local $size = UBound($clickList)
            ReDim $clickList[$size + 1][2]
            $clickList[$size][0] = $x
            $clickList[$size][1] = $y
        Next
        
        If UBound($clickList) = 0 Then
            MsgBox($MB_ICONERROR, "Error", "No valid multi-click coordinates found for device: " & $selectedDevice, 5)
            Return
        EndIf
    Else
        ; Single click fallback
        Local $btnX = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonX", "")
        Local $btnY = IniRead($gamesFile, "Device_" & $selectedDevice, "ImportButtonY", "")
        
        If $btnX = "" Or $btnY = "" Then
            MsgBox($MB_ICONERROR, "Error", "Import button coordinates not set for device: " & $selectedDevice, 5)
            Return
        EndIf
        
        ReDim $clickList[1][2]
        $clickList[0][0] = $btnX
        $clickList[0][1] = $btnY
    EndIf
    
    ; Extract process name
    Local $processName = StringRegExpReplace($currentDeviceGuiExe, ".*\\", "")
    
    ; Launch device GUI if not running
    If Not ProcessExists($processName) Then
        Run($currentDeviceGuiExe)
        Sleep(1500)
    EndIf
    
    ; Wait for window to appear
    Local $winFound = False
    For $i = 1 To 50 ; Wait up to 5 seconds
        Local $winList = WinList("[CLASS:#32770]")
        If $winList[0][0] > 0 Then
            $winFound = True
            ExitLoop
        EndIf
        $winList = WinList("[TITLE:*Device*]")
        If $winList[0][0] > 0 Then
            $winFound = True
            ExitLoop
        EndIf
        $winList = WinList("[TITLE:*GUI*]")
        If $winList[0][0] > 0 Then
            $winFound = True
            ExitLoop
        EndIf
        Sleep(100)
    Next
    
    If Not $winFound Then
        MsgBox($MB_ICONERROR, "Error", "Could not find Device GUI window after launching.", 5)
        Return
    EndIf
    
    ; Activate window
    Local $activated = False
    Local $winList = WinList("[CLASS:#32770]")
    For $i = 1 To $winList[0][0]
        If $winList[$i][0] <> "" Then
            WinActivate($winList[$i][1])
            $activated = True
            ExitLoop
        EndIf
    Next
    
    If Not $activated Then
        $winList = WinList("[TITLE:*Device*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    If Not $activated Then
        $winList = WinList("[TITLE:*GUI*]")
        For $i = 1 To $winList[0][0]
            If $winList[$i][0] <> "" Then
                WinActivate($winList[$i][1])
                $activated = True
                ExitLoop
            EndIf
        Next
    EndIf
    
    Sleep(300)
    
    ; Get current click delay
    Local $currentClickDelay = _GetDeviceClickDelay($selectedDevice)
    
    ; Perform clicks
    For $i = 0 To UBound($clickList) - 1
        MouseMove($clickList[$i][0], $clickList[$i][1], 10)
        Sleep(100)
        MouseClick("left")
        
        If $i < UBound($clickList) - 1 Then
            Sleep($currentClickDelay)
        EndIf
    Next
    
    ; Wait for file dialog
    $winFound = False
    For $i = 1 To 100 ; Wait up to 10 seconds
        $winList = WinList("[CLASS:#32770]")
        If $winList[0][0] > 0 Then
            $winFound = True
            ExitLoop
        EndIf
        Sleep(100)
    Next
    
    If Not $winFound Then
        MsgBox($MB_ICONERROR, "GUI Not Loaded Properly", _
            "File open dialog did not appear." & @CRLF & @CRLF & _
            "Possible issues:" & @CRLF & _
            "- Device GUI is not responding" & @CRLF & _
            "- Import button coordinates may be incorrect" & @CRLF & _
            "- Device software may need to be restarted", 10)
        Return
    EndIf
    
    ; Interact with file dialog
    $winList = WinList("[CLASS:#32770]")
    If $winList[0][0] > 0 Then
        WinActivate($winList[1][1])
    EndIf
    Sleep(600)
    
    ; Set file path in dialog
    ControlSetText("[CLASS:#32770]", "", "Edit1", $profilePath)
    Sleep(300)
    
    ; Press Enter
    ControlSend("[CLASS:#32770]", "", "Edit1", "{ENTER}")
    Sleep(300)
    
    ; If dialog still exists, click Open button
    $winList = WinList("[CLASS:#32770]")
    If $winList[0][0] > 0 Then
        ; Try to find and click the Open button
        Local $hWnd = $winList[1][1]
        If $hWnd Then
            ; Different strategies to click the button
            ControlClick($hWnd, "", "Button1") ; Usually "Open" or "OK" button
            Sleep(300)
            
            ; Also try sending Alt+O (for Open) or Alt+S (for Save/Select)
            ControlSend($hWnd, "", "", "!o")
            Sleep(300)
            ControlSend($hWnd, "", "", "!s")
        EndIf
    EndIf
    
    Sleep(500)
    
    ; Use custom delay if provided, otherwise default
    Local $delayToUse = ($customDelay <> "") ? $customDelay : $defaultProfileDelay
    Sleep($delayToUse)
    
    ; Handle GUI minimization/closure
    If $minimizeGuiAfterImport = 1 And ProcessExists($processName) Then
        ; Minimize instead of close
        Local $winHandle = 0
        $winList = WinList("[CLASS:#32770]")
        If $winList[0][0] > 0 Then
            $winHandle = $winList[1][1]
        Else
            $winList = WinList("[TITLE:*Device*]")
            If $winList[0][0] > 0 Then
                $winHandle = $winList[1][1]
            EndIf
        EndIf
        
        If $winHandle Then
            WinSetState($winHandle, "", @SW_MINIMIZE)
            MsgBox($MB_ICONINFORMATION, "GUI Minimized", _
                "Device GUI minimized." & @CRLF & @CRLF & _
                "It will stay running in the background." & @CRLF & _
                "You can close it manually from system tray if needed.", 5)
        EndIf
    Else
        ; Try gentle closure sequence
        If ProcessExists($processName) Then
            ; Method 1: Try closing window normally
            Local $winHandle = 0
            $winList = WinList("[CLASS:#32770]")
            If $winList[0][0] > 0 Then
                $winHandle = $winList[1][1]
            EndIf
            
            If $winHandle Then
                WinClose($winHandle)
                Sleep(1000)
            EndIf
            
            ; Check if still running
            If ProcessExists($processName) Then
                ; Method 2: Send Alt+F4
                Local $winHandle = 0
                $winList = WinList("[CLASS:#32770]")
                If $winList[0][0] > 0 Then
                    $winHandle = $winList[1][1]
                EndIf
                
                If $winHandle Then
                    WinActivate($winHandle)
                    Sleep(100)
                    Send("!{F4}")
                    Sleep(1000)
                EndIf
                
                ; Method 3: Force close if still running
                If ProcessExists($processName) Then
                    ProcessClose($processName)
                EndIf
            EndIf
        EndIf
    EndIf
    
    MsgBox($MB_ICONINFORMATION, "Success", "Profile imported successfully: " & @CRLF & _
        StringRegExpReplace($profilePath, ".*\\", ""))
EndFunc

; ===== GUI INITIALIZATION =====
Func _CreateModernGUI()
    $mainGui = GUICreate("XB Profile Manager", 900, 800, -1, -1, BitOR($WS_SIZEBOX, $WS_MINIMIZEBOX, $WS_MAXIMIZEBOX))
    GUISetBkColor($bgColorCfg, $mainGui)
    GUISetFont(9, 400, 0, "Segoe UI")
    GUISetOnEvent($GUI_EVENT_CLOSE, "_ExitApp")
    
    ; Title bar
    $titleBar = GUICtrlCreateLabel("XB Profile Manager", 12, 12, 400, 36)
    GUICtrlSetFont($titleBar, 13, 700)
    GUICtrlSetColor($titleBar, $textColorCfg)
    GUICtrlSetBkColor($titleBar, $GUI_BKCOLOR_TRANSPARENT)
    
    ; Window control buttons
    $hMin = GUICtrlCreateLabel("−", 810, 12, 40, 36, $SS_CENTER)
    $hClose = GUICtrlCreateLabel("×", 850, 12, 40, 36, $SS_CENTER)
    GUICtrlSetFont($hMin, 16)
    GUICtrlSetFont($hClose, 16)
    GUICtrlSetColor($hMin, $textColorCfg)
    GUICtrlSetColor($hClose, $textColorCfg)
    GUICtrlSetBkColor($hMin, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetBkColor($hClose, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetOnEvent($hMin, "_MinimizeWindow")
    GUICtrlSetOnEvent($hClose, "_ExitApp")
    
    ; Tabs area background
    GUICtrlCreateLabel("", 0, 58, 900, 50)
    GUICtrlSetBkColor(-1, 0x1E1E1E)
    
    ; Create tabs
    Local $aTabNames[4] = ["Game Launcher", "Profile Manager", "Game Editor", "Settings"]
    Local $tabWidth = 200
    Local $tabSpacing = 10
    
    For $i = 0 To UBound($aTabNames) - 1
        Local $xPos = 20 + ($i * ($tabWidth + $tabSpacing))
        $hTabs[$i] = GUICtrlCreateLabel($aTabNames[$i], $xPos, 38, $tabWidth, 36, $SS_CENTER)
        GUICtrlSetFont($hTabs[$i], 11, 500)
        GUICtrlSetColor($hTabs[$i], $textColorCfg)
        GUICtrlSetBkColor($hTabs[$i], $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetOnEvent($hTabs[$i], "_TabClicked")
        GUICtrlSetCursor($hTabs[$i], 0)
    Next
    
    ; Active tab indicator line
    $hLine = GUICtrlCreateLabel("", 20 + ($iActive * ($tabWidth + $tabSpacing)), 70, $tabWidth, 4)
    GUICtrlSetBkColor($hLine, 0x3B82F6)
    
    ; Main content area
    GUICtrlCreateLabel("", 20, 90, 860, 650)
    GUICtrlSetBkColor(-1, 0x1E1E1E)
    
    ; Create tab content
    _CreateTab1_GameLauncher()
    _CreateTab2_ProfileManager()
    _CreateTab3_GameEditor()
    _CreateTab4_Settings()
    
    ; Exit button
    Local $exitBtn = GUICtrlCreateButton("Exit", 700, 750, 150, 48)
    GUICtrlSetFont($exitBtn, 11, 600)
    GUICtrlSetBkColor($exitBtn, 0xEF4444)
    GUICtrlSetColor($exitBtn, 0xFFFFFF)
    GUICtrlSetOnEvent($exitBtn, "_ExitApp")
    
    ; Activate first tab
    _ActivateFirstTab()
EndFunc

Func _CreateTab1_GameLauncher()
    ; Device dropdown
    GUICtrlCreateLabel("Device:", 40, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $launcherDeviceDrop = GUICtrlCreateCombo("", 130, 117, 200, 25, $CBS_DROPDOWNLIST)
    _AddToTab(0, $launcherDeviceDrop)
    GUICtrlSetOnEvent($launcherDeviceDrop, "_HandleDeviceChange")
    
    ; Search
    GUICtrlCreateLabel("Search:", 350, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $launcherSearchEdit = GUICtrlCreateInput("", 430, 117, 200, 25)
    _AddToTab(0, $launcherSearchEdit)
    GUICtrlSetOnEvent($launcherSearchEdit, "_FilterLauncherList")
    
    ; Games list
    Local $label1 = GUICtrlCreateLabel("Select Game:", 40, 160, 800, 25, $SS_CENTER)
    GUICtrlSetColor($label1, $textColorCfg)
    _AddToTab(0, $label1)
    
    $lbLauncher = GUICtrlCreateList("", 40, 190, 800, 250)
    _AddToTab(0, $lbLauncher)
    GUICtrlSetOnEvent($lbLauncher, "_LauncherGameSelected")
    
    ; Selection label
    $launcherSelLabel = GUICtrlCreateLabel("", 40, 450, 800, 25)
    _AddToTab(0, $launcherSelLabel)
    
    ; Notes
    Local $notesLabel1 = GUICtrlCreateLabel("Notes for selected game:", 40, 485, 200, 25)
    GUICtrlSetColor($notesLabel1, $textColorCfg)
    _AddToTab(0, $notesLabel1)
    
    $launcherNotesEdit = GUICtrlCreateEdit("", 40, 510, 800, 80, BitOR($ES_WANTRETURN, $WS_VSCROLL, $WS_BORDER))
    _AddToTab(0, $launcherNotesEdit)
    
    ; Buttons
    $launchBtn = GUICtrlCreateButton("Launch Game", 40, 600, 250, 40)
    _AddToTab(0, $launchBtn)
    GUICtrlSetOnEvent($launchBtn, "_LaunchSelectedGame")
    GUICtrlSetBkColor($launchBtn, 0x3B82F6)
    GUICtrlSetColor($launchBtn, 0xFFFFFF)
    
    $launcherOpenFolderBtn = GUICtrlCreateButton("Open Profiles Folder", 310, 600, 250, 40)
    _AddToTab(0, $launcherOpenFolderBtn)
    GUICtrlSetOnEvent($launcherOpenFolderBtn, "_OpenCurrentDeviceProfileFolder")
    GUICtrlSetBkColor($launcherOpenFolderBtn, 0x10B981)
    GUICtrlSetColor($launcherOpenFolderBtn, 0xFFFFFF)
    
    $launcherLaunchEditorBtn = GUICtrlCreateButton("Launch Device GUI Editor", 580, 600, 250, 40)
    _AddToTab(0, $launcherLaunchEditorBtn)
    GUICtrlSetOnEvent($launcherLaunchEditorBtn, "_LaunchDeviceGuiEditor")
    GUICtrlSetBkColor($launcherLaunchEditorBtn, 0xF59E0B)
    GUICtrlSetColor($launcherLaunchEditorBtn, 0xFFFFFF)
    
    ; Hide all controls initially
    For $i = 0 To $tabControlCount[0] - 1
        If $tabContent[0][$i] > 0 Then
            GUICtrlSetState($tabContent[0][$i], $GUI_HIDE)
        EndIf
    Next
EndFunc

Func _CreateTab2_ProfileManager()
    ; Similar structure for Tab 2
    GUICtrlCreateLabel("Device:", 40, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $profilesDeviceDrop = GUICtrlCreateCombo("", 130, 117, 200, 25, $CBS_DROPDOWNLIST)
    _AddToTab(1, $profilesDeviceDrop)
    GUICtrlSetOnEvent($profilesDeviceDrop, "_HandleDeviceChange")
    
    ; Search
    GUICtrlCreateLabel("Search:", 350, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $profilesSearchEdit = GUICtrlCreateInput("", 430, 117, 200, 25)
    _AddToTab(1, $profilesSearchEdit)
    GUICtrlSetOnEvent($profilesSearchEdit, "_FilterProfilesList")
    
    ; Profiles list
    Local $label2 = GUICtrlCreateLabel("Select Profile:", 40, 160, 800, 25, $SS_CENTER)
    GUICtrlSetColor($label2, $textColorCfg)
    _AddToTab(1, $label2)
    
    $lbProfiles = GUICtrlCreateList("", 40, 190, 800, 250)
    _AddToTab(1, $lbProfiles)
    GUICtrlSetOnEvent($lbProfiles, "_ProfileSelected")
    
    ; Selection label
    $profileSelLabel = GUICtrlCreateLabel("", 40, 450, 800, 25)
    _AddToTab(1, $profileSelLabel)
    
    ; Notes
    Local $notesLabel2 = GUICtrlCreateLabel("Notes for selected profile:", 40, 485, 200, 25)
    GUICtrlSetColor($notesLabel2, $textColorCfg)
    _AddToTab(1, $notesLabel2)
    
    $profilesNotesEdit = GUICtrlCreateEdit("", 40, 510, 800, 80, BitOR($ES_WANTRETURN, $WS_VSCROLL, $WS_BORDER))
    _AddToTab(1, $profilesNotesEdit)
    
    ; Buttons
    $profilesImportBtn = GUICtrlCreateButton("Import Profile", 40, 600, 190, 40)
    _AddToTab(1, $profilesImportBtn)
    GUICtrlSetOnEvent($profilesImportBtn, "_ImportSelectedProfile")
    GUICtrlSetBkColor($profilesImportBtn, 0xA855F7)
    GUICtrlSetColor($profilesImportBtn, 0xFFFFFF)
    
    $profilesOpenFolderBtn = GUICtrlCreateButton("Open Profiles Folder", 240, 600, 190, 40)
    _AddToTab(1, $profilesOpenFolderBtn)
    GUICtrlSetOnEvent($profilesOpenFolderBtn, "_OpenCurrentDeviceProfileFolder")
    GUICtrlSetBkColor($profilesOpenFolderBtn, 0x10B981)
    GUICtrlSetColor($profilesOpenFolderBtn, 0xFFFFFF)
    
    $profilesBackupBtn = GUICtrlCreateButton("Backup Profile", 440, 600, 190, 40)
    _AddToTab(1, $profilesBackupBtn)
    GUICtrlSetOnEvent($profilesBackupBtn, "_BackupSelectedProfile")
    GUICtrlSetBkColor($profilesBackupBtn, 0x06B6D4)
    GUICtrlSetColor($profilesBackupBtn, 0xFFFFFF)
    
    $profilesSetFolderBtn = GUICtrlCreateButton("Set Profiles Folder", 640, 600, 190, 40)
    _AddToTab(1, $profilesSetFolderBtn)
    GUICtrlSetOnEvent($profilesSetFolderBtn, "_SelectProfilesFolder")
    GUICtrlSetBkColor($profilesSetFolderBtn, 0xF59E0B)
    GUICtrlSetColor($profilesSetFolderBtn, 0xFFFFFF)
    
    ; Hide all controls initially
    For $i = 0 To $tabControlCount[1] - 1
        If $tabContent[1][$i] > 0 Then
            GUICtrlSetState($tabContent[1][$i], $GUI_HIDE)
        EndIf
    Next
EndFunc

Func _CreateTab3_GameEditor()
    ; Device dropdown
    GUICtrlCreateLabel("Device:", 40, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $editorDeviceDrop = GUICtrlCreateCombo("", 130, 117, 200, 25, $CBS_DROPDOWNLIST)
    _AddToTab(2, $editorDeviceDrop)
    GUICtrlSetOnEvent($editorDeviceDrop, "_HandleDeviceChange")
    
    ; Search
    GUICtrlCreateLabel("Search:", 350, 120, 80, 25)
    GUICtrlSetColor(-1, $textColorCfg)
    $editorSearchEdit = GUICtrlCreateInput("", 430, 117, 200, 25)
    _AddToTab(2, $editorSearchEdit)
    GUICtrlSetOnEvent($editorSearchEdit, "_FilterGamesList")
    
    ; Games list
    Local $label3 = GUICtrlCreateLabel("Select Game:", 40, 160, 800, 25, $SS_CENTER)
    GUICtrlSetColor($label3, $textColorCfg)
    _AddToTab(2, $label3)
    
    $lbGames = GUICtrlCreateList("", 40, 190, 800, 200)
    _AddToTab(2, $lbGames)
    GUICtrlSetOnEvent($lbGames, "_PopulateGameFields")
    
    ; Selection label
    $selGameLabel = GUICtrlCreateLabel("", 40, 400, 800, 25)
    _AddToTab(2, $selGameLabel)
    
    ; Buttons row 1
    $editorAddBtn = GUICtrlCreateButton("Add / Update", 40, 430, 190, 40)
    _AddToTab(2, $editorAddBtn)
    GUICtrlSetOnEvent($editorAddBtn, "_AddOrUpdateGame")
    GUICtrlSetBkColor($editorAddBtn, 0x10B981)
    GUICtrlSetColor($editorAddBtn, 0xFFFFFF)
    
    $editorRemoveBtn = GUICtrlCreateButton("Remove", 240, 430, 190, 40)
    _AddToTab(2, $editorRemoveBtn)
    GUICtrlSetOnEvent($editorRemoveBtn, "_RemoveSelectedGame")
    GUICtrlSetBkColor($editorRemoveBtn, 0xEF4444)
    GUICtrlSetColor($editorRemoveBtn, 0xFFFFFF)
    
    $editorCreateShortcutBtn = GUICtrlCreateButton("Create Shortcut", 440, 430, 190, 40)
    _AddToTab(2, $editorCreateShortcutBtn)
    GUICtrlSetOnEvent($editorCreateShortcutBtn, "_CreateGameShortcut")
    GUICtrlSetBkColor($editorCreateShortcutBtn, 0x3B82F6)
    GUICtrlSetColor($editorCreateShortcutBtn, 0xFFFFFF)
    
    $editorClearBtn = GUICtrlCreateButton("Clear Fields", 640, 430, 190, 40)
    _AddToTab(2, $editorClearBtn)
    GUICtrlSetOnEvent($editorClearBtn, "_ClearEditorFields")
    GUICtrlSetBkColor($editorClearBtn, 0xF59E0B)
    GUICtrlSetColor($editorClearBtn, 0xFFFFFF)
    
    ; Game EXE Path
    Local $exeLabel = GUICtrlCreateLabel("Game EXE Path:", 40, 480, 150, 25)
    GUICtrlSetColor($exeLabel, $textColorCfg)
    _AddToTab(2, $exeLabel)
    
    $gameExeEdit = GUICtrlCreateInput("", 40, 505, 690, 25)
    _AddToTab(2, $gameExeEdit)
    
    $editorBrowseExeBtn = GUICtrlCreateButton("Browse", 740, 505, 100, 25)
    _AddToTab(2, $editorBrowseExeBtn)
    GUICtrlSetOnEvent($editorBrowseExeBtn, "_BrowseGameExe")
    
    $editorOpenExeFolderBtn = GUICtrlCreateButton("Open EXE Folder", 740, 535, 100, 25)
    _AddToTab(2, $editorOpenExeFolderBtn)
    GUICtrlSetOnEvent($editorOpenExeFolderBtn, "_OpenExeFolder")
    
    ; Game Name
    Local $nameLabel = GUICtrlCreateLabel("Game Name:", 40, 570, 150, 25)
    GUICtrlSetColor($nameLabel, $textColorCfg)
    _AddToTab(2, $nameLabel)
    
    $gameNameEdit = GUICtrlCreateInput("", 40, 595, 800, 25)
    _AddToTab(2, $gameNameEdit)
    
    ; Profile Path
    Local $profileLabel = GUICtrlCreateLabel("Profile Path:", 40, 630, 150, 25)
    GUICtrlSetColor($profileLabel, $textColorCfg)
    _AddToTab(2, $profileLabel)
    
    $gameProfileEdit = GUICtrlCreateInput("", 40, 655, 690, 25)
    _AddToTab(2, $gameProfileEdit)
    
    $editorBrowseProfileBtn = GUICtrlCreateButton("Browse", 740, 655, 100, 25)
    _AddToTab(2, $editorBrowseProfileBtn)
    GUICtrlSetOnEvent($editorBrowseProfileBtn, "_BrowseProfileFile")
    
    ; Delays and options
    Local $delayLabel = GUICtrlCreateLabel("Game Launch Delay (ms):", 40, 690, 200, 25)
    GUICtrlSetColor($delayLabel, $textColorCfg)
    _AddToTab(2, $delayLabel)
    
    $gameDelayEdit = GUICtrlCreateInput("1500", 240, 687, 100, 25)
    _AddToTab(2, $gameDelayEdit)
    
    $launchExeCheckbox = GUICtrlCreateCheckbox("Launch with EXE", 350, 690, 150, 25)
    _AddToTab(2, $launchExeCheckbox)
    GUICtrlSetState($launchExeCheckbox, $GUI_CHECKED)
    GUICtrlSetColor($launchExeCheckbox, $textColorCfg)
    
    $closeManagerCheckbox = GUICtrlCreateCheckbox("Close Manager after Launch", 510, 690, 200, 25)
    _AddToTab(2, $closeManagerCheckbox)
    GUICtrlSetState($closeManagerCheckbox, $GUI_CHECKED)
    GUICtrlSetColor($closeManagerCheckbox, $textColorCfg)
    
    Local $guiDelayLabel = GUICtrlCreateLabel("GUI Close Delay (ms):", 40, 720, 150, 25)
    GUICtrlSetColor($guiDelayLabel, $textColorCfg)
    _AddToTab(2, $guiDelayLabel)
    
    $guiCloseDelayEdit = GUICtrlCreateInput("1000", 200, 717, 100, 25)
    _AddToTab(2, $guiCloseDelayEdit)
    
    ; Hide all controls initially
    For $i = 0 To $tabControlCount[2] - 1
        If $tabContent[2][$i] > 0 Then
            GUICtrlSetState($tabContent[2][$i], $GUI_HIDE)
        EndIf
    Next
EndFunc

Func _CreateTab4_Settings()
    ; Colors section
    Local $colorsLabel = GUICtrlCreateLabel("Colors", 40, 120, 800, 25, $SS_CENTER)
    GUICtrlSetFont($colorsLabel, 11, 700)
    GUICtrlSetColor($colorsLabel, $textColorCfg)
    _AddToTab(3, $colorsLabel)
    
    Local $bgLabel = GUICtrlCreateLabel("BG Color:", 40, 160, 100, 25)
    GUICtrlSetColor($bgLabel, $textColorCfg)
    _AddToTab(3, $bgLabel)
    
    $bgColorBtn = GUICtrlCreateButton("Pick", 150, 157, 100, 30)
    _AddToTab(3, $bgColorBtn)
    GUICtrlSetOnEvent($bgColorBtn, "_PickBackgroundColor")
    
    $textColorPreview = GUICtrlCreateLabel("Text Preview", 270, 160, 600, 30, BitOR($SS_CENTER, $SS_SUNKEN))
    _AddToTab(3, $textColorPreview)
    GUICtrlSetFont($textColorPreview, 11)
    
    ; Sorting section
    Local $sortLabel = GUICtrlCreateLabel("Sorting", 40, 210, 800, 25, $SS_CENTER)
    GUICtrlSetFont($sortLabel, 11, 700)
    GUICtrlSetColor($sortLabel, $textColorCfg)
    _AddToTab(3, $sortLabel)
    
    Local $sortByLabel = GUICtrlCreateLabel("Sort Games By:", 40, 250, 120, 25)
    GUICtrlSetColor($sortByLabel, $textColorCfg)
    _AddToTab(3, $sortByLabel)
    
    $gamesSortDrop = GUICtrlCreateCombo("", 170, 247, 150, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($gamesSortDrop, "Alphabetical|TimeAdded|LastPlayed", "Alphabetical")
    _AddToTab(3, $gamesSortDrop)
    GUICtrlSetOnEvent($gamesSortDrop, "_SortSettingsChanged")
    
    Local $orderLabel = GUICtrlCreateLabel("Order:", 340, 250, 50, 25)
    GUICtrlSetColor($orderLabel, $textColorCfg)
    _AddToTab(3, $orderLabel)
    
    $orderSortDrop = GUICtrlCreateCombo("", 400, 247, 100, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($orderSortDrop, "Ascending|Descending", "Ascending")
    _AddToTab(3, $orderSortDrop)
    GUICtrlSetOnEvent($orderSortDrop, "_SortSettingsChanged")
    
    ; Device GUI Automation section
    Local $autoLabel = GUICtrlCreateLabel("Device GUI Automation", 40, 300, 800, 25, $SS_CENTER)
    GUICtrlSetFont($autoLabel, 11, 700)
    GUICtrlSetColor($autoLabel, $textColorCfg)
    _AddToTab(3, $autoLabel)
    
    ; Buttons row 1
    $launchEditorBtn = GUICtrlCreateButton("Launch Device GUI Editor", 40, 340, 250, 35)
    _AddToTab(3, $launchEditorBtn)
    GUICtrlSetOnEvent($launchEditorBtn, "_LaunchDeviceGuiEditor")
    
    $captureImportBtn = GUICtrlCreateButton("Capture Import Button", 310, 340, 250, 35)
    _AddToTab(3, $captureImportBtn)
    GUICtrlSetOnEvent($captureImportBtn, "_CaptureImportButtonCoords")
    
    $openProfilesBtn = GUICtrlCreateButton("Open Program Folder", 580, 340, 250, 35)
    _AddToTab(3, $openProfilesBtn)
    GUICtrlSetOnEvent($openProfilesBtn, "_OpenProgramFolder")
    
    ; Buttons row 2
    $testImportBtn = GUICtrlCreateButton("Test Import Click", 40, 385, 250, 35)
    _AddToTab(3, $testImportBtn)
    GUICtrlSetOnEvent($testImportBtn, "_TestImportClick")
    
    $selectDeviceGuiExeBtn = GUICtrlCreateButton("Select Device GUI EXE", 310, 385, 250, 35)
    _AddToTab(3, $selectDeviceGuiExeBtn)
    GUICtrlSetOnEvent($selectDeviceGuiExeBtn, "_SelectDeviceGuiExe")
    
    $openProfileFolderBtn = GUICtrlCreateButton("Open Profile Folder", 580, 385, 250, 35)
    _AddToTab(3, $openProfileFolderBtn)
    GUICtrlSetOnEvent($openProfileFolderBtn, "_OpenCurrentDeviceProfileFolder")
    
    ; Click delay setting
    Local $delayLabel2 = GUICtrlCreateLabel("Click Delay (ms):", 40, 440, 120, 25)
    GUICtrlSetColor($delayLabel2, $textColorCfg)
    _AddToTab(3, $delayLabel2)
    
    $clickDelayEdit = GUICtrlCreateInput("300", 170, 437, 80, 25)
    _AddToTab(3, $clickDelayEdit)
    
    $saveDelayBtn = GUICtrlCreateButton("Save Click Delay", 260, 437, 130, 25)
    _AddToTab(3, $saveDelayBtn)
    GUICtrlSetOnEvent($saveDelayBtn, "_SaveDelayBtn_Click")
    
    ; Minimize GUI checkbox
    $minimizeGuiCheckbox = GUICtrlCreateCheckbox("Minimize GUI after import", 40, 480, 200, 25)
    _AddToTab(3, $minimizeGuiCheckbox)
    GUICtrlSetOnEvent($minimizeGuiCheckbox, "_SaveMinimizeGuiSetting")
    GUICtrlSetColor($minimizeGuiCheckbox, $textColorCfg)
    
    ; Profile folder button
    $selectDeviceProfileDirBtn = GUICtrlCreateButton("Set Device Profile Folder", 40, 520, 350, 35)
    _AddToTab(3, $selectDeviceProfileDirBtn)
    GUICtrlSetOnEvent($selectDeviceProfileDirBtn, "_SelectDeviceProfileDir")
    
    ; Devices section
    Local $devicesLabel = GUICtrlCreateLabel("Devices", 40, 570, 800, 25, $SS_CENTER)
    GUICtrlSetFont($devicesLabel, 11, 700)
    GUICtrlSetColor($devicesLabel, $textColorCfg)
    _AddToTab(3, $devicesLabel)
    
    Local $deviceLabel = GUICtrlCreateLabel("Device:", 40, 610, 80, 25)
    GUICtrlSetColor($deviceLabel, $textColorCfg)
    _AddToTab(3, $deviceLabel)
    
    $devicesDrop = GUICtrlCreateCombo("", 130, 607, 200, 25, $CBS_DROPDOWNLIST)
    _AddToTab(3, $devicesDrop)
    GUICtrlSetOnEvent($devicesDrop, "_HandleDeviceChange")
    
    $addDeviceBtn = GUICtrlCreateButton("Add", 350, 607, 70, 25)
    _AddToTab(3, $addDeviceBtn)
    GUICtrlSetOnEvent($addDeviceBtn, "_AddNewDevice")
    
    $deleteDeviceBtn = GUICtrlCreateButton("Delete", 430, 607, 70, 25)
    _AddToTab(3, $deleteDeviceBtn)
    GUICtrlSetOnEvent($deleteDeviceBtn, "_DeleteSelectedDevice")
    
    ; Profile extension
    Local $extLabel = GUICtrlCreateLabel("Profile Ext:", 40, 650, 120, 25)
    GUICtrlSetColor($extLabel, $textColorCfg)
    _AddToTab(3, $extLabel)
    
    $profileExtDrop = GUICtrlCreateCombo("", 130, 647, 140, 25, $CBS_DROPDOWNLIST)
    _AddToTab(3, $profileExtDrop)
    GUICtrlSetOnEvent($profileExtDrop, "_ProfileExtChanged")
    
    $addExtEdit = GUICtrlCreateInput("", 280, 647, 70, 25)
    _AddToTab(3, $addExtEdit)
    
    $addExtBtn = GUICtrlCreateButton("Add Ext", 360, 647, 80, 25)
    _AddToTab(3, $addExtBtn)
    GUICtrlSetOnEvent($addExtBtn, "_AddExtensionToDevice")
    
    ; Hide all controls initially
    For $i = 0 To $tabControlCount[3] - 1
        If $tabContent[3][$i] > 0 Then
            GUICtrlSetState($tabContent[3][$i], $GUI_HIDE)
        EndIf
    Next
EndFunc

Func _ActivateFirstTab()
    ; Manually activate the first tab
    $iActive = 0
    
    ; Update tab colors
    For $i = 0 To UBound($hTabs) - 1
        If $i = $iActive Then
            GUICtrlSetFont($hTabs[$i], 11, 700)
            GUICtrlSetColor($hTabs[$i], 0xFFFFFF)
        Else
            GUICtrlSetFont($hTabs[$i], 11, 500)
            GUICtrlSetColor($hTabs[$i], 0xAAAAAA)
        EndIf
    Next
    
    ; Move indicator line
    Local $xPos = 20 + ($iActive * (200 + 10))
    GUICtrlSetPos($hLine, $xPos, 70)
    
    ; Hide all tab content
    For $tab = 0 To 3
        For $j = 0 To $tabControlCount[$tab] - 1
            If $tabContent[$tab][$j] > 0 Then
                GUICtrlSetState($tabContent[$tab][$j], $GUI_HIDE)
            EndIf
        Next
    Next
    
    ; Show first tab content
    For $j = 0 To $tabControlCount[0] - 1
        If $tabContent[0][$j] > 0 Then
            GUICtrlSetState($tabContent[0][$j], $GUI_SHOW)
        EndIf
    Next
EndFunc

; ===== EVENT HANDLERS =====
Func _TabClicked()
    ; Find which tab was clicked
    For $i = 0 To UBound($hTabs) - 1
        If @GUI_CtrlId = $hTabs[$i] Then
            $iActive = $i
            ExitLoop
        EndIf
    Next
    
    ; Update tab colors
    For $i = 0 To UBound($hTabs) - 1
        If $i = $iActive Then
            GUICtrlSetFont($hTabs[$i], 11, 700)
            GUICtrlSetColor($hTabs[$i], 0xFFFFFF)
        Else
            GUICtrlSetFont($hTabs[$i], 11, 500)
            GUICtrlSetColor($hTabs[$i], 0xAAAAAA)
        EndIf
    Next
    
    ; Move indicator line
    Local $xPos = 20 + ($iActive * (200 + 10))
    GUICtrlSetPos($hLine, $xPos, 70)
    
    ; Hide all tab content
    For $tab = 0 To 3
        For $j = 0 To $tabControlCount[$tab] - 1
            If $tabContent[$tab][$j] > 0 Then
                GUICtrlSetState($tabContent[$tab][$j], $GUI_HIDE)
            EndIf
        Next
    Next
    
    ; Show current tab content
    For $j = 0 To $tabControlCount[$iActive] - 1
        If $tabContent[$iActive][$j] > 0 Then
            GUICtrlSetState($tabContent[$iActive][$j], $GUI_SHOW)
        EndIf
    Next
EndFunc

Func _HandleDeviceChange()
    ; Handle device change event
    Local $newDevice = ""
    
    ; Determine which dropdown was changed
    Switch @GUI_CtrlId
        Case $launcherDeviceDrop
            $newDevice = GUICtrlRead($launcherDeviceDrop)
        Case $profilesDeviceDrop
            $newDevice = GUICtrlRead($profilesDeviceDrop)
        Case $editorDeviceDrop
            $newDevice = GUICtrlRead($editorDeviceDrop)
        Case $devicesDrop
            $newDevice = GUICtrlRead($devicesDrop)
    EndSwitch
    
    If $newDevice = "" Then Return
    
    $selectedDevice = $newDevice
    IniWrite($gamesFile, "Config", "SelectedDevice", $selectedDevice)
    
    ; Update all dropdowns
    _PopulateAllDeviceDropdowns()
    
    ; Update current profile extension
    For $i = 0 To UBound($deviceCurrentExt) - 1
        If $deviceCurrentExt[$i][0] = $selectedDevice Then
            $currentProfileExtension = $deviceCurrentExt[$i][1]
            ExitLoop
        EndIf
    Next
    
    ; Update click delay display
    Local $currentDelay = _GetDeviceClickDelay($selectedDevice)
    GUICtrlSetData($clickDelayEdit, $currentDelay)
    
    ; Populate profile extension dropdown
    _PopulateProfileExtDrop()
    
    ; Refresh lists
    _PopulateGameListControls()
    _PopulateProfileList()
EndFunc

Func _FilterLauncherList()
    ; Filter launcher list
    Local $searchText = GUICtrlRead($launcherSearchEdit)
    _PopulateGameListControls($searchText)
EndFunc

Func _LauncherGameSelected()
    ; Handle game selection in launcher
    Local $selectedGame = GUICtrlRead($lbLauncher)
    If $selectedGame = "" Then Return
    
    GUICtrlSetData($launcherSelLabel, "Selected: " & $selectedGame)
    ; TODO: Load notes for selected game
EndFunc

Func _LaunchSelectedGame()
    Local $selectedGame = GUICtrlRead($lbLauncher)
    If $selectedGame = "" Then
        MsgBox($MB_ICONWARNING, "No Game Selected", "Please select a game first")
        Return
    EndIf
    
    Local $gameName = _GetBaseGameName($selectedGame)
    
    ; Find game data
    Local $gameIndex = -1
    For $i = 0 To UBound($gameNames) - 1
        If $gameNames[$i] = $gameName Then
            $gameIndex = $i
            ExitLoop
        EndIf
    Next
    
    If $gameIndex = -1 Then
        MsgBox($MB_ICONERROR, "Error", "Game data not found: " & $gameName)
        Return
    EndIf
    
    ; Get game data
    Local $exe = $games[$gameIndex][1]
    Local $profile = _GetGameProfileForDevice($gameName, $selectedDevice)
    Local $delay = $games[$gameIndex][3]
    Local $launch = $games[$gameIndex][4]
    Local $closeManager = $games[$gameIndex][5]
    Local $guiCloseDelay = IniRead($gamesFile, "Games", $gameName & ".GuiCloseDelay", $defaultProfileDelay)
    
    ; Update last played and launch count
    Local $lastPlayed = _CurrentIsoTimestamp()
    Local $launchCount = $games[$gameIndex][8] + 1
    
    ; Save updated info
    _SaveGameToIni($gameName, $exe, $profile, $delay, $launch, _
        $games[$gameIndex][6], $lastPlayed, $launchCount, $closeManager)
    
    ; Import profile if exists
    If $profile <> "" And FileExists($profile) Then
        _ImportProfile($profile, $guiCloseDelay)
    EndIf
    
    ; Launch game if configured to do so
    If $launch = 1 And $exe <> "" Then
        If $delay > 0 Then
            Sleep($delay)
        EndIf
        
        ; Launch the game
        ShellExecute($exe, "", StringLeft($exe, StringInStr($exe, "\", 0, -1) - 1))
        
        ; Close manager if configured
        If $closeManager = 1 Then
            Sleep(500)
            _ExitApp()
        EndIf
    Else
        ; Just close if configured
        If $closeManager = 1 Then
            Sleep(500)
            _ExitApp()
        EndIf
    EndIf
EndFunc

Func _OpenCurrentDeviceProfileFolder()
    ; Open profile folder
    Local $folder = _GetDeviceProfileDir($selectedDevice)
    If FileExists($folder) Then
        Run("explorer.exe " & $folder)
    Else
        MsgBox($MB_ICONWARNING, "Folder Not Found", "Profile folder does not exist:" & @CRLF & $folder)
    EndIf
EndFunc

Func _LaunchDeviceGuiEditor()
    ; Launch device GUI editor (stub for now)
    MsgBox($MB_ICONINFORMATION, "Info", "Launching Device GUI Editor...")
EndFunc

Func _FilterProfilesList()
    ; Filter profiles list (stub for now)
    Local $searchText = GUICtrlRead($profilesSearchEdit)
    _PopulateProfileList($searchText)
EndFunc

Func _ProfileSelected()
    ; Handle profile selection
    Local $selectedProfile = GUICtrlRead($lbProfiles)
    If $selectedProfile = "" Then Return
    
    GUICtrlSetData($profileSelLabel, "Selected: " & $selectedProfile)
    ; TODO: Load notes for selected profile
EndFunc

Func _ImportSelectedProfile()
    Local $selectedProfile = GUICtrlRead($lbProfiles)
    If $selectedProfile = "" Then
        MsgBox($MB_ICONWARNING, "No Profile Selected", "Please select a profile first")
        Return
    EndIf
    
    Local $profileDir = _GetDeviceProfileDir($selectedDevice)
    Local $profilePath = $profileDir & "\" & $selectedProfile
    
    ; Get GUI close delay for this profile if associated with a game
    Local $guiCloseDelay = $defaultProfileDelay
    For $i = 0 To UBound($games) - 1
        If $games[$i][2] = $profilePath Then ; Check if profile matches
            Local $gameName = $games[$i][0]
            $guiCloseDelay = IniRead($gamesFile, "Games", $gameName & ".GuiCloseDelay", $defaultProfileDelay)
            ExitLoop
        EndIf
    Next
    
    _ImportProfile($profilePath, $guiCloseDelay)
EndFunc

Func _BackupSelectedProfile()
    ; Backup selected profile (stub for now)
    Local $selectedProfile = GUICtrlRead($lbProfiles)
    If $selectedProfile = "" Then
        MsgBox($MB_ICONWARNING, "No Profile Selected", "Please select a profile first")
        Return
    EndIf
    
    MsgBox($MB_ICONINFORMATION, "Info", "Backing up profile: " & $selectedProfile)
EndFunc

Func _SelectProfilesFolder()
    ; Select profiles folder - only allow subfolders
    Local $folder = FileSelectFolder("Choose Profiles Folder", $scriptDir, 3, $scriptDir)
    If $folder <> "" Then
        ; Ensure it's within script directory
        If StringLeft($folder, StringLen($scriptDir)) = $scriptDir Then
            $profilesDir = $folder
            IniWrite($gamesFile, "Config", "ProfilesDir", $profilesDir)
            MsgBox($MB_ICONINFORMATION, "Success", "Profiles folder set to:" & @CRLF & $folder)
            _PopulateProfileList()
        Else
            MsgBox($MB_ICONERROR, "Error", "Please select a folder within the program directory")
        EndIf
    EndIf
EndFunc

Func _FilterGamesList()
    ; Filter games list (stub for now)
    Local $searchText = GUICtrlRead($editorSearchEdit)
    _PopulateGameListControls($searchText, True)
EndFunc

Func _PopulateGameFields()
    ; Populate game fields when a game is selected in editor
    Local $selectedGame = GUICtrlRead($lbGames)
    If $selectedGame = "" Then
        GUICtrlSetData($selGameLabel, "")
        Return
    EndIf
    
    GUICtrlSetData($selGameLabel, "Selected: " & $selectedGame)
    
    ; Find the game in our array
    Local $gameName = _GetBaseGameName($selectedGame)
    Local $gameIndex = -1
    
    For $i = 0 To UBound($gameNames) - 1
        If $gameNames[$i] = $gameName Then
            $gameIndex = $i
            ExitLoop
        EndIf
    Next
    
    If $gameIndex = -1 Then Return
    
    ; Populate fields
    GUICtrlSetData($gameNameEdit, $gameName)
    GUICtrlSetData($gameExeEdit, $games[$gameIndex][1])
    
    ; Get profile for current device
    Local $profile = _GetGameProfileForDevice($gameName, $selectedDevice)
    GUICtrlSetData($gameProfileEdit, $profile)
    
    GUICtrlSetData($gameDelayEdit, $games[$gameIndex][3])
    GUICtrlSetState($launchExeCheckbox, $games[$gameIndex][4] ? $GUI_CHECKED : $GUI_UNCHECKED)
    GUICtrlSetState($closeManagerCheckbox, $games[$gameIndex][5] ? $GUI_CHECKED : $GUI_UNCHECKED)
    
    ; Get GUI close delay
    Local $guiCloseDelay = IniRead($gamesFile, "Games", $gameName & ".GuiCloseDelay", $defaultProfileDelay)
    GUICtrlSetData($guiCloseDelayEdit, $guiCloseDelay)
EndFunc

Func _AddOrUpdateGame()
    ; Add or update game
    Local $gameName = StringStripWS(GUICtrlRead($gameNameEdit), 3)
    Local $exe = StringStripWS(GUICtrlRead($gameExeEdit), 3)
    Local $profile = StringStripWS(GUICtrlRead($gameProfileEdit), 3)
    Local $delay = StringStripWS(GUICtrlRead($gameDelayEdit), 3)
    Local $launch = (GUICtrlRead($launchExeCheckbox) = $GUI_CHECKED) ? 1 : 0
    Local $closeManager = (GUICtrlRead($closeManagerCheckbox) = $GUI_CHECKED) ? 1 : 0
    Local $guiCloseDelay = StringStripWS(GUICtrlRead($guiCloseDelayEdit), 3)
    
    If $gameName = "" Then
        MsgBox($MB_ICONWARNING, "Error", "Game name cannot be empty")
        Return
    EndIf
    
    ; Check if this is a new game or an update
    Local $gameIndex = -1
    For $i = 0 To UBound($gameNames) - 1
        If $gameNames[$i] = $gameName Then
            $gameIndex = $i
            ExitLoop
        EndIf
    Next
    
    Local $added = ""
    If $gameIndex = -1 Then
        ; New game
        $added = _CurrentIsoTimestamp()
    Else
        ; Update existing game
        $added = $games[$gameIndex][6]
    EndIf
    
    ; Save to INI
    _SaveGameToIni($gameName, $exe, $profile, $delay, $launch, $added, "", "", $closeManager)
    
    ; Save GUI close delay
    If $guiCloseDelay <> "" And StringRegExp($guiCloseDelay, "^\d+$") Then
        IniWrite($gamesFile, "Games", $gameName & ".GuiCloseDelay", $guiCloseDelay)
    EndIf
    
    ; Reload games
    _LoadGames()
    _PopulateGameListControls()
    
    MsgBox($MB_ICONINFORMATION, "Success", "Game saved for device: " & $selectedDevice)
EndFunc

Func _RemoveSelectedGame()
    ; Remove selected game
    Local $selectedGame = GUICtrlRead($lbGames)
    If $selectedGame = "" Then
        MsgBox($MB_ICONWARNING, "Error", "No game selected")
        Return
    EndIf
    
    Local $gameName = _GetBaseGameName($selectedGame)
    
    ; Remove profile for current device
    Local $key = StringRegExpReplace($gameName, "\s", "")
    Local $deviceProfileKey = $key & ".Profile" & $selectedDevice
    IniDelete($gamesFile, "Games", $deviceProfileKey)
    
    Local $oldKey = $key & $selectedDevice & ".Profiles"
    IniDelete($gamesFile, "Games", $oldKey)
    
    ; Check if game has profiles for other devices
    Local $hasOtherProfiles = False
    For $dev In $devices
        If $dev = $selectedDevice Then ContinueLoop
        
        Local $otherProfileKey = $key & ".Profile" & $dev
        Local $otherProfile = IniRead($gamesFile, "Games", $otherProfileKey, "")
        
        If $otherProfile <> "" Then
            $hasOtherProfiles = True
            ExitLoop
        EndIf
        
        Local $otherOldKey = $key & $dev & ".Profiles"
        $otherProfile = IniRead($gamesFile, "Games", $otherOldKey, "")
        
        If $otherProfile <> "" Then
            $hasOtherProfiles = True
            ExitLoop
        EndIf
    Next
    
    If Not $hasOtherProfiles Then
        ; Remove entire game entry
        If MsgBox($MB_YESNO + $MB_ICONQUESTION, "Confirm Removal", "This game has no profiles for other devices. Remove entire game entry?") = $IDYES Then
            _RemoveGameFromIni($gameName)
            IniDelete($gamesFile, "Games", $gameName & ".GuiCloseDelay")
        EndIf
    EndIf
    
    ; Reload and refresh
    _LoadGames()
    _PopulateGameListControls()
    
    MsgBox($MB_ICONINFORMATION, "Success", "Profile removed for device: " & $selectedDevice)
EndFunc

Func _CreateGameShortcut()
    ; Create game shortcut (stub for now)
    Local $selectedGame = GUICtrlRead($lbGames)
    If $selectedGame = "" Then
        MsgBox($MB_ICONWARNING, "Error", "No game selected")
        Return
    EndIf
    
    MsgBox($MB_ICONINFORMATION, "Info", "Creating shortcut for: " & $selectedGame)
EndFunc

Func _ClearEditorFields()
    ; Clear editor fields
    GUICtrlSetData($gameExeEdit, "")
    GUICtrlSetData($gameNameEdit, "")
    GUICtrlSetData($gameProfileEdit, "")
    GUICtrlSetData($gameDelayEdit, "1500")
    GUICtrlSetState($launchExeCheckbox, $GUI_CHECKED)
    GUICtrlSetState($closeManagerCheckbox, $GUI_CHECKED)
    GUICtrlSetData($guiCloseDelayEdit, "1000")
    GUICtrlSetData($selGameLabel, "")
    GUICtrlSetState($lbGames, $GUI_UNCHECKED)
EndFunc

Func _BrowseGameExe()
    ; Browse for game EXE - start from script directory
    Local $file = FileOpenDialog("Select Game EXE", $lastExeDir, "Executables (*.exe)", 3)
    If $file <> "" Then
        GUICtrlSetData($gameExeEdit, $file)
        ; Extract game name from filename
        Local $name = StringTrimRight(StringRegExpReplace($file, ".*\\", ""), 4)
        GUICtrlSetData($gameNameEdit, $name)
        $lastExeDir = StringLeft($file, StringInStr($file, "\", 0, -1) - 1)
        IniWrite($gamesFile, "Config", "LastExeDir", $lastExeDir)
    EndIf
EndFunc

Func _OpenExeFolder()
    ; Open EXE folder
    Local $exe = GUICtrlRead($gameExeEdit)
    If $exe <> "" Then
        Local $folder = StringLeft($exe, StringInStr($exe, "\", 0, -1) - 1)
        Run("explorer.exe " & $folder)
    EndIf
EndFunc

Func _BrowseProfileFile()
    ; Browse for profile file - start from current device profile directory
    Local $currentDir = _GetDeviceProfileDir($selectedDevice)
    Local $file = FileOpenDialog("Select Profile File", $currentDir, "All Files (*.*)", 3)
    If $file <> "" Then
        GUICtrlSetData($gameProfileEdit, $file)
    EndIf
EndFunc

Func _PickBackgroundColor()
    ; Pick background color (stub for now)
    MsgBox($MB_ICONINFORMATION, "Info", "Color picker would open here")
EndFunc

Func _SortSettingsChanged()
    ; Handle sort settings change
    $sortGamesMode = GUICtrlRead($gamesSortDrop)
    $sortOrder = GUICtrlRead($orderSortDrop)
    
    IniWrite($gamesFile, "Sort", "Games", $sortGamesMode)
    IniWrite($gamesFile, "Sort", "Order", $sortOrder)
    
    _PopulateGameListControls()
    _PopulateProfileList()
EndFunc

Func _OpenProgramFolder()
    ; Open program folder (script directory)
    Run("explorer.exe " & $scriptDir)
EndFunc

Func _SelectDeviceGuiExe()
    ; Select device GUI EXE - start from script directory
    Local $file = FileOpenDialog("Select Device GUI EXE", $scriptDir, "Executables (*.exe)", 3)
    If $file <> "" Then
        ; Store in device settings
        For $i = 0 To UBound($deviceGuiExe) - 1
            If $deviceGuiExe[$i][0] = $selectedDevice Then
                $deviceGuiExe[$i][1] = $file
                ExitLoop
            EndIf
        Next
        
        ; If not found, add it
        If $i = UBound($deviceGuiExe) Then
            Local $size = UBound($deviceGuiExe)
            ReDim $deviceGuiExe[$size + 1][2]
            $deviceGuiExe[$size][0] = $selectedDevice
            $deviceGuiExe[$size][1] = $file
        EndIf
        
        ; Save to INI
        IniWrite($gamesFile, "Device_" & $selectedDevice, "DeviceGuiExe", $file)
        
        MsgBox($MB_ICONINFORMATION, "Success", "Device GUI EXE set for " & $selectedDevice & " to:" & @CRLF & $file)
    EndIf
EndFunc

Func _SaveDelayBtn_Click()
    ; Save click delay
    Local $delay = StringStripWS(GUICtrlRead($clickDelayEdit), 3)
    If $delay = "" Or Not StringRegExp($delay, "^\d+$") Then
        MsgBox($MB_ICONWARNING, "Invalid Input", "Please enter a valid number for click delay")
        Return
    EndIf
    
    Local $delayValue = Int($delay)
    If $delayValue < 0 Then
        MsgBox($MB_ICONWARNING, "Invalid Input", "Click delay cannot be negative")
        Return
    EndIf
    
    ; Update device click delay
    For $i = 0 To UBound($deviceClickDelay) - 1
        If $deviceClickDelay[$i][0] = $selectedDevice Then
            $deviceClickDelay[$i][1] = $delayValue
            ExitLoop
        EndIf
    Next
    
    ; If not found, add it
    If $i = UBound($deviceClickDelay) Then
        Local $size = UBound($deviceClickDelay)
        ReDim $deviceClickDelay[$size + 1][2]
        $deviceClickDelay[$size][0] = $selectedDevice
        $deviceClickDelay[$size][1] = $delayValue
    EndIf
    
    ; Save to INI
    IniWrite($gamesFile, "Device_" & $selectedDevice, "ClickDelay", $delayValue)
    
    MsgBox($MB_ICONINFORMATION, "Success", "Click delay saved for device " & $selectedDevice & ": " & $delayValue & "ms")
EndFunc

Func _SaveMinimizeGuiSetting()
    ; Save minimize GUI setting
    $minimizeGuiAfterImport = (GUICtrlRead($minimizeGuiCheckbox) = $GUI_CHECKED) ? 1 : 0
    IniWrite($gamesFile, "Config", "MinimizeGuiAfterImport", $minimizeGuiAfterImport)
    MsgBox($MB_ICONINFORMATION, "Success", "Setting saved: " & ($minimizeGuiAfterImport ? "GUI will minimize after import" : "GUI will close after import"))
EndFunc

Func _SelectDeviceProfileDir()
    ; Select device profile directory - only allow subfolders
    Local $currentDir = _GetDeviceProfileDir($selectedDevice)
    Local $folder = FileSelectFolder("Choose Device Profile Folder", $scriptDir, 3, $currentDir)
    If $folder <> "" Then
        ; Ensure it's within script directory
        If StringLeft($folder, StringLen($scriptDir)) = $scriptDir Then
            ; Update device profile directory
            For $i = 0 To UBound($deviceProfileDir) - 1
                If $deviceProfileDir[$i][0] = $selectedDevice Then
                    $deviceProfileDir[$i][1] = $folder
                    ExitLoop
                EndIf
            Next
            
            ; If not found, add it
            If $i = UBound($deviceProfileDir) Then
                Local $size = UBound($deviceProfileDir)
                ReDim $deviceProfileDir[$size + 1][2]
                $deviceProfileDir[$size][0] = $selectedDevice
                $deviceProfileDir[$size][1] = $folder
            EndIf
            
            ; Save to INI
            IniWrite($gamesFile, "Device_" & $selectedDevice, "ProfileDir", $folder)
            
            MsgBox($MB_ICONINFORMATION, "Success", "Profile folder set for device " & $selectedDevice & " to:" & @CRLF & $folder)
            
            ; Refresh profile list
            If $iActive = 1 Then ; Profile Manager tab
                _PopulateProfileList()
            EndIf
        Else
            MsgBox($MB_ICONERROR, "Error", "Please select a folder within the program directory")
        EndIf
    EndIf
EndFunc

Func _AddNewDevice()
    ; Add new device
    Local $name = InputBox("Add New Device", "Enter new device name:", "")
    $name = StringStripWS($name, 3)
    
    If $name = "" Then Return
    
    If _DeviceExists($name) Then
        MsgBox($MB_ICONWARNING, "Duplicate Device", "A device with that name already exists")
        Return
    EndIf
    
    ; Add to devices array
    _ArrayAdd($devices, $name)
    
    ; Add to device extensions arrays
    Local $size = UBound($deviceExtensions)
    ReDim $deviceExtensions[$size + 1][2]
    $deviceExtensions[$size][0] = $name
    $deviceExtensions[$size][1] = StringSplit("", ",", 2) ; Empty array
    
    $size = UBound($deviceCurrentExt)
    ReDim $deviceCurrentExt[$size + 1][2]
    $deviceCurrentExt[$size][0] = $name
    $deviceCurrentExt[$size][1] = "*"
    
    ; Add to other device arrays
    $size = UBound($deviceGuiExe)
    ReDim $deviceGuiExe[$size + 1][2]
    $deviceGuiExe[$size][0] = $name
    $deviceGuiExe[$size][1] = ""
    
    $size = UBound($deviceClickDelay)
    ReDim $deviceClickDelay[$size + 1][2]
    $deviceClickDelay[$size][0] = $name
    $deviceClickDelay[$size][1] = $clickDelayGlobal
    
    $size = UBound($deviceProfileDir)
    ReDim $deviceProfileDir[$size + 1][2]
    $deviceProfileDir[$size][0] = $name
    $deviceProfileDir[$size][1] = $profilesDir
    
    ; Save to INI
    Local $deviceCount = UBound($devices)
    IniWrite($gamesFile, "Devices", "Device" & $deviceCount, $name)
    IniWrite($gamesFile, "DeviceCurrentExt", $name, "*")
    IniWrite($gamesFile, "Device_" & $name, "ClickDelay", $clickDelayGlobal)
    IniWrite($gamesFile, "Device_" & $name, "ProfileDir", $profilesDir)
    
    $selectedDevice = $name
    IniWrite($gamesFile, "Config", "SelectedDevice", $selectedDevice)
    
    ; Refresh UI
    _PopulateAllDeviceDropdowns()
    _PopulateProfileExtDrop()
    _PopulateGameListControls()
    _PopulateProfileList()
    
    MsgBox($MB_ICONINFORMATION, "Success", "Device added: " & $name)
EndFunc

Func _DeleteSelectedDevice()
    ; Delete selected device
    If $selectedDevice = "" Then
        MsgBox($MB_ICONWARNING, "No Device Selected", "Please select a device first")
        Return
    EndIf
    
    If UBound($devices) = 1 Then
        MsgBox($MB_ICONWARNING, "Cannot Delete", "You must have at least one device")
        Return
    EndIf
    
    If MsgBox($MB_YESNO + $MB_ICONQUESTION, "Confirm Delete", "Delete device '" & $selectedDevice & "' and all its settings?") <> $IDYES Then
        Return
    EndIf
    
    ; Create new arrays without the deleted device
    Local $newDevices[0]
    For $dev In $devices
        If $dev <> $selectedDevice Then
            _ArrayAdd($newDevices, $dev)
        EndIf
    Next
    
    $devices = $newDevices
    
    ; Rebuild device-specific arrays
    Local $newDeviceExtensions[0][0]
    Local $newDeviceCurrentExt[0][0]
    Local $newDeviceGuiExe[0][0]
    Local $newDeviceClickDelay[0][0]
    Local $newDeviceProfileDir[0][0]
    
    For $dev In $devices
        ; Copy extensions
        For $i = 0 To UBound($deviceExtensions) - 1
            If $deviceExtensions[$i][0] = $dev Then
                Local $size = UBound($newDeviceExtensions)
                ReDim $newDeviceExtensions[$size + 1][2]
                $newDeviceExtensions[$size][0] = $dev
                $newDeviceExtensions[$size][1] = $deviceExtensions[$i][1]
                ExitLoop
            EndIf
        Next
        
        ; Copy current extension
        For $i = 0 To UBound($deviceCurrentExt) - 1
            If $deviceCurrentExt[$i][0] = $dev Then
                Local $size = UBound($newDeviceCurrentExt)
                ReDim $newDeviceCurrentExt[$size + 1][2]
                $newDeviceCurrentExt[$size][0] = $dev
                $newDeviceCurrentExt[$size][1] = $deviceCurrentExt[$i][1]
                ExitLoop
            EndIf
        Next
        
        ; Copy GUI exe
        For $i = 0 To UBound($deviceGuiExe) - 1
            If $deviceGuiExe[$i][0] = $dev Then
                Local $size = UBound($newDeviceGuiExe)
                ReDim $newDeviceGuiExe[$size + 1][2]
                $newDeviceGuiExe[$size][0] = $dev
                $newDeviceGuiExe[$size][1] = $deviceGuiExe[$i][1]
                ExitLoop
            EndIf
        Next
        
        ; Copy click delay
        For $i = 0 To UBound($deviceClickDelay) - 1
            If $deviceClickDelay[$i][0] = $dev Then
                Local $size = UBound($newDeviceClickDelay)
                ReDim $newDeviceClickDelay[$size + 1][2]
                $newDeviceClickDelay[$size][0] = $dev
                $newDeviceClickDelay[$size][1] = $deviceClickDelay[$i][1]
                ExitLoop
            EndIf
        Next
        
        ; Copy profile dir
        For $i = 0 To UBound($deviceProfileDir) - 1
            If $deviceProfileDir[$i][0] = $dev Then
                Local $size = UBound($newDeviceProfileDir)
                ReDim $newDeviceProfileDir[$size + 1][2]
                $newDeviceProfileDir[$size][0] = $dev
                $newDeviceProfileDir[$size][1] = $deviceProfileDir[$i][1]
                ExitLoop
            EndIf
        Next
    Next
    
    $deviceExtensions = $newDeviceExtensions
    $deviceCurrentExt = $newDeviceCurrentExt
    $deviceGuiExe = $newDeviceGuiExe
    $deviceClickDelay = $newDeviceClickDelay
    $deviceProfileDir = $newDeviceProfileDir
    
    ; Update INI
    IniDelete($gamesFile, "Devices")
    For $i = 0 To UBound($devices) - 1
        IniWrite($gamesFile, "Devices", "Device" & ($i + 1), $devices[$i])
    Next
    
    IniDelete($gamesFile, "DeviceExtensions", $selectedDevice)
    IniDelete($gamesFile, "DeviceCurrentExt", $selectedDevice)
    IniDelete($gamesFile, "Device_" & $selectedDevice)
    
    ; Select new device
    $selectedDevice = $devices[0]
    IniWrite($gamesFile, "Config", "SelectedDevice", $selectedDevice)
    
    ; Refresh UI
    _PopulateAllDeviceDropdowns()
    _PopulateProfileExtDrop()
    _PopulateGameListControls()
    _PopulateProfileList()
    
    MsgBox($MB_ICONINFORMATION, "Success", "Device deleted: " & $selectedDevice)
EndFunc

Func _ProfileExtChanged()
    ; Handle profile extension change
    Local $selectedExt = GUICtrlRead($profileExtDrop)
    If $selectedExt = "" Then Return
    
    If $selectedExt = "* (All)" Then
        $currentProfileExtension = "*"
    Else
        ; Remove leading dot if present
        If StringLeft($selectedExt, 1) = "." Then
            $selectedExt = StringMid($selectedExt, 2)
        EndIf
        $currentProfileExtension = $selectedExt
    EndIf
    
    ; Update device current extension
    For $i = 0 To UBound($deviceCurrentExt) - 1
        If $deviceCurrentExt[$i][0] = $selectedDevice Then
            $deviceCurrentExt[$i][1] = $currentProfileExtension
            ExitLoop
        EndIf
    Next
    
    _SaveDeviceExtensionsToIni()
    _PopulateProfileList()
EndFunc

Func _AddExtensionToDevice()
    ; Add extension to device
    Local $ext = StringStripWS(GUICtrlRead($addExtEdit), 3)
    If $ext = "" Then Return
    
    ; Remove leading dot if present
    If StringLeft($ext, 1) = "." Then
        $ext = StringMid($ext, 2)
    EndIf
    
    ; Validate extension (3 characters, letters/numbers)
    If StringLen($ext) <> 3 Or Not StringRegExp($ext, "^[A-Za-z0-9]{3}$") Then
        MsgBox($MB_ICONWARNING, "Invalid Extension", "Please enter a 3-character extension (letters/numbers)")
        Return
    EndIf
    
    $ext = StringLower($ext)
    
    ; Check if extension already exists for this device
    For $i = 0 To UBound($deviceExtensions) - 1
        If $deviceExtensions[$i][0] = $selectedDevice Then
            Local $extArr = $deviceExtensions[$i][1]
            For $e In $extArr
                If StringLower($e) = $ext Then
                    MsgBox($MB_ICONWARNING, "Duplicate Extension", "That extension already exists for this device")
                    Return
                EndIf
            Next
            
            ; Add extension
            _ArrayAdd($extArr, $ext)
            $deviceExtensions[$i][1] = $extArr
            
            ; If this is the first extension, set it as current
            If UBound($extArr) = 1 Then
                For $j = 0 To UBound($deviceCurrentExt) - 1
                    If $deviceCurrentExt[$j][0] = $selectedDevice Then
                        $deviceCurrentExt[$j][1] = $ext
                        $currentProfileExtension = $ext
                        ExitLoop
                    EndIf
                Next
            EndIf
            
            ExitLoop
        EndIf
    Next
    
    _SaveDeviceExtensionsToIni()
    _PopulateProfileExtDrop()
    _PopulateProfileList()
    
    GUICtrlSetData($addExtEdit, "")
    MsgBox($MB_ICONINFORMATION, "Success", "Extension added: " & $ext)
EndFunc

Func _MinimizeWindow()
    WinSetState($mainGui, "", @SW_MINIMIZE)
EndFunc

Func _ExitApp()
    ; Clean up hotkey if registered
    If $f8HotkeyRegistered Then
        HotKeySet("{F8}")
        $f8HotkeyRegistered = False
    EndIf
    
    ; Close overlay if open
    If $overlayGui <> 0 Then
        GUIDelete($overlayGui)
        $overlayGui = 0
    EndIf
    
    ; Save window position
    Local $pos = WinGetPos($mainGui)
    If Not @error Then
        IniWrite($gamesFile, "Config", "WinX", $pos[0])
        IniWrite($gamesFile, "Config", "WinY", $pos[1])
    EndIf
    
    ; Save current tab
    IniWrite($gamesFile, "Config", "LastTab", $iActive + 1)
    
    Exit
EndFunc

; ===== UI POPULATION FUNCTIONS =====
Func _PopulateAllDeviceDropdowns()
    ; Populate device dropdowns in all tabs
    Local $dropdowns[4] = [$devicesDrop, $launcherDeviceDrop, $profilesDeviceDrop, $editorDeviceDrop]
    
    For $dropdown In $dropdowns
        GUICtrlSetData($dropdown, "|")
        For $dev In $devices
            GUICtrlSetData($dropdown, $dev)
        Next
        
        ; Select current device
        If $selectedDevice <> "" Then
            GUICtrlSetData($dropdown, $selectedDevice)
        EndIf
    Next
EndFunc

Func _PopulateProfileExtDrop()
    ; Populate profile extension dropdown
    GUICtrlSetData($profileExtDrop, "|")
    
    ; Add "All" option
    GUICtrlSetData($profileExtDrop, "* (All)")
    
    ; Find extensions for current device
    For $i = 0 To UBound($deviceExtensions) - 1
        If $deviceExtensions[$i][0] = $selectedDevice Then
            Local $extArr = $deviceExtensions[$i][1]
            For $ext In $extArr
                GUICtrlSetData($profileExtDrop, "." & $ext)
            Next
            ExitLoop
        EndIf
    Next
    
    ; Select current extension
    If $currentProfileExtension = "*" Then
        GUICtrlSetData($profileExtDrop, "* (All)")
    Else
        GUICtrlSetData($profileExtDrop, "." & $currentProfileExtension)
    EndIf
EndFunc

Func _PopulateGameListControls($searchText = "", $editorTab = False)
    ; Populate game lists in launcher and editor
    Local $targetList, $filteredNames
    
    If $editorTab Then
        $targetList = $lbGames
        ; Get all games for editor
        $filteredNames = $gameNames
    Else
        $targetList = $lbLauncher
        ; Get games for current device
        $filteredNames = _GetGamesForCurrentDevice()
    EndIf
    
    ; Clear list
    GUICtrlSetData($targetList, "")
    
    ; Apply search filter
    If $searchText <> "" Then
        Local $filtered[0]
        Local $searchLower = StringLower($searchText)
        
        For $name In $filteredNames
            Local $displayName = $name & " (" & $selectedDevice & ")"
            If StringInStr(StringLower($displayName), $searchLower) Then
                _ArrayAdd($filtered, $displayName)
            EndIf
        Next
        
        $filteredNames = $filtered
    Else
        ; Add device suffix for display
        Local $displayNames[0]
        For $name In $filteredNames
            _ArrayAdd($displayNames, $name & " (" & $selectedDevice & ")")
        Next
        $filteredNames = $displayNames
    EndIf
    
    ; Add to list
    For $name In $filteredNames
        GUICtrlSetData($targetList, $name)
    Next
EndFunc

Func _PopulateProfileList($searchText = "")
    ; Populate profile list
    Local $profileDir = _GetDeviceProfileDir($selectedDevice)
    
    GUICtrlSetData($lbProfiles, "")
    
    If Not FileExists($profileDir) Then
        Return
    EndIf
    
    ; Get files matching current extension
    Local $searchPattern
    If $currentProfileExtension = "*" Then
        $searchPattern = "*.*"
    Else
        $searchPattern = "*." & $currentProfileExtension
    EndIf
    
    Local $files = _FileListToArray($profileDir, $searchPattern, 1)
    If @error Then Return
    
    ; Apply search filter
    Local $filtered[0]
    For $i = 1 To $files[0]
        If $searchText = "" Or StringInStr(StringLower($files[$i]), StringLower($searchText)) Then
            _ArrayAdd($filtered, $files[$i])
        EndIf
    Next
    
    ; Add to list
    For $file In $filtered
        GUICtrlSetData($lbProfiles, $file)
    Next
EndFunc

; ===== MAIN PROGRAM =====
_EnsureDefaultFolders() ; Create necessary subfolders

; Initialize INI file if it doesn't exist
If Not FileExists($gamesFile) Then
    _EnsureDefaultIniKeys()
EndIf

_LoadConfig() ; Load configuration
_LoadDevices() ; Load devices
_LoadDeviceExtensions() ; Load device extensions
_LoadGames() ; Load games
_RepairGamesIni() ; Repair old INI format
_LoadProfiles() ; Load profile notes

_CreateModernGUI()
_FixControlColors() ; Fix colors for readability

; Update UI with loaded data
_PopulateAllDeviceDropdowns()
_PopulateProfileExtDrop()
_PopulateGameListControls()
_PopulateProfileList()

; Update click delay display
Local $currentDelay = _GetDeviceClickDelay($selectedDevice)
GUICtrlSetData($clickDelayEdit, $currentDelay)

; Update minimize GUI checkbox
GUICtrlSetState($minimizeGuiCheckbox, $minimizeGuiAfterImport ? $GUI_CHECKED : $GUI_UNCHECKED)

; Update sort dropdowns
GUICtrlSetData($gamesSortDrop, $sortGamesMode)
GUICtrlSetData($orderSortDrop, $sortOrder)

; Show GUI
GUISetState(@SW_SHOW, $mainGui)

; Main loop
While 1
    Sleep(100)
WEnd