### Action autocomplete
# Since this script can be sourced multiple times, only try to add the base actions once per context.
if(!$script:BASE_ACTIONS_ADDED)
{
    $script:AVAIL_ACTIONS += @{
        'help' = 'ShowActionList';
        "$script:TARGET.elf" = 'DoElf';
        "$script:TARGET.bin" = 'DoBin';
        'closechlink' = 'DoCloseCHLink';
        'terminal' = 'DoMonitor';
        'monitor' = 'DoMonitor';
        'gdbserver' = 'DoGDBServer';
        'cv_flash' = 'DoCVFlash';
        'cv_clean' = 'DoCVClean';
        'build' = 'DoBin';
    };
    $script:BASE_ACTIONS_ADDED = $true;
}

# This dynamically creates a parameter for autocomplete of possible actions.
function CreateActionParam
{
    $AttrColl = [System.Collections.ObjectModel.Collection[System.Attribute]]::new();

    $ParamAttr = [System.Management.Automation.ParameterAttribute]::new();
    $ParamAttr.Mandatory = $true;
    $ParamAttr.Position = 0;
    $AttrColl.Add($ParamAttr);

    $ValidateAttr = [System.Management.Automation.ValidateSetAttribute]::new($script:AVAIL_ACTIONS.Keys);
    $AttrColl.Add($ValidateAttr);

    $DefinedParam = [System.Management.Automation.RuntimeDefinedParameter]::new('Actions', [String[]], $AttrColl);
    $ParamDict = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new();
    $ParamDict.Add('Actions', $DefinedParam);
    return $ParamDict;
}

# If we're just getting autocomplete options, don't run any further to save time.
if ($script:ACTIONS_ENUM_ONLY) { return; }

### Globals
if($null -EQ $script:PREFIX) { $script:PREFIX = 'riscv64-unknown-elf'; }
if($null -EQ $script:CH32V003FUN) { $script:CH32V003FUN = '../../ch32v003fun'; }
if($null -EQ $script:MINICHLINK) { $script:MINICHLINK = '../../minichlink'; }
$script:CFLAGS += @(
    '-g', '-Os', '-flto', '-ffunction-sections',
	'-static-libgcc',
	'-march=rv32ec',
	'-mabi=ilp32e',
	'-I/usr/include/newlib',
	"-I$CH32V003FUN/../extralibs",
	"-I$CH32V003FUN",
	'-nostdlib',
	'-I.', '-Wall'
);
$script:LDFLAGS += @('-T', "$CH32V003FUN/ch32v003fun.ld", '-Wl,--gc-sections', "-L$CH32V003FUN/../misc", '-lgcc');
$script:SYSTEM_C = "$CH32V003FUN/ch32v003fun.c";
$script:TARGET_EXT = 'c';

### Helper Functions
# Magic, IDK
function Flatten($Nest) { ,@($Nest | % { if($null -NE $_) {$_} }); }

# Runs the defined action by name
function ExecuteActions($ActionsToRun)
{
    if ($ActionsToRun -is [string]) { Invoke-Expression $script:AVAIL_ACTIONS[$ActionsToRun]; }
    else
    { 
        foreach($ActionToRun in $ActionsToRun)
        {
            Invoke-Expression $script:AVAIL_ACTIONS[$ActionToRun];
        }
    }
}

function ShowActionList
{
    $ActionNames = Flatten $script:AVAIL_ACTIONS.Keys;
    $ActionNames = $ActionNames | Sort-Object {"$_"};
    Write-Host "Available actions: $ActionNames";
}

### Build Procedures
# Define procedures
function DoElf
{
    $TargetWithExt = "$script:TARGET.$script:TARGET_EXT";
    if ($script:OVERRIDE_C) { $TargetWithExt = $script:OVERRIDE_C; }
    $RequiredFiles = @($script:SYSTEM_C, $TargetWithExt, $script:ADDITIONAL_C_FILES);
    $RequiredFiles = Flatten $RequiredFiles;

    foreach ($Prerequisite in $RequiredFiles)
    {
        if (!(Test-Path $Prerequisite)) { throw "The file '$Prerequisite' is required."; }
    }

    [string[]] $ProcArgs = @('-o', "$script:TARGET.elf", $RequiredFiles, $script:CFLAGS, $script:LDFLAGS);
    $CompilerProc = Start-Process -NoNewWindow -Wait "$script:PREFIX-gcc" -ArgumentList $ProcArgs -PassThru;
    if ($CompilerProc.ExitCode -NE 0) { throw "The compiler returned exit code $($CompilerProc.ExitCode)."; }
}

function DoBin
{
    DoElf;
    Start-Process -Wait -NoNewWindow "$script:PREFIX-size" -ArgumentList @("$script:TARGET.elf"); # Wait for this to finish, then do the rest in parallel
    $Processes = @();
    $Processes += Start-Process -NoNewWindow -PassThru "$script:PREFIX-objdump" -ArgumentList @('-S', "$script:TARGET.elf") -RedirectStandardOutput "$script:TARGET.lst";
    $Processes += Start-Process -NoNewWindow -PassThru "$script:PREFIX-objdump" -ArgumentList @('-t', "$script:TARGET.elf") -RedirectStandardOutput "$script:TARGET.map";
    $Processes += Start-Process -NoNewWindow -PassThru "$script:PREFIX-objcopy" -ArgumentList @('-O', 'binary', "$script:TARGET.elf", "$script:TARGET.bin");
    $Processes += Start-Process -NoNewWindow -PassThru "$script:PREFIX-objcopy" -ArgumentList @('-O', 'ihex', "$script:TARGET.elf", "$script:TARGET.hex");
    foreach ($Proc in $Processes) { $Proc.WaitForExit(); }
}

function DoCloseCHLink
{
    if ([System.Environment]::OSVersion.Platform -EQ 'Win32NT')
    {
        & taskkill /F /IM minichlink.exe /T
    }
    else
    {
        & killall minichlink
    }
}

function DoMonitor
{
    Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-T');
}

function DoGDBServer
{
    Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-baG');
}

function DoCVFlash()
{
    DoBin;
    $FlashProc = Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-w', "$script:TARGET.bin", 'flash', '-b') -PassThru;
    if ($FlashProc.ExitCode -NE 0) { throw "The programmer returned exit code $($FlashProc.ExitCode)."; }
}

function DoCVClean()
{
    Remove-Item @("$script:TARGET.elf", "$script:TARGET.bin", "$script:TARGET.hex", "$script:TARGET.lst", "$script:TARGET.map", "$script:TARGET.hex") -ErrorAction SilentlyContinue;
    if ($Error[0] -notmatch 'does not exist') { Write-Error $Error[0]; } # In case something else went wrong while deleting the file
    # TODO: The above might not work on non-English OSes.
}

# It must be ensured that sourcing this script does not cause it to do anything but define functions and set global variables.
