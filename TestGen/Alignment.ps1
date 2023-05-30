# Generates two of every instruction, one aligned and one unaligned.
# This is used to determine if the alignment of any individual instruction matters, but does not check the relationship between alignments of multiple instructions.

[CmdletBinding()]
param (
    [Parameter()]
    [switch] $NoCapture,
    [switch] $ManualCapture,
    [switch] $NoProgram,
    [switch] $NonInteractive,
    [switch] $RandomOrder
)

$ErrorActionPreference = 'Stop';
$script:PREFIX = $null;
$script:CH32V003FUN = $null;
$script:MINICHLINK = $null;
$script:CFLAGS = $null;
$script:LDFLAGS = $null;
$script:SYSTEM_C = $null;
$script:TARGET_EXT = $null;
$script:TARGET = $null;
$script:OVERRIDE_C = $null;
$script:ADDITIONAL_C_FILES = $null;

$TEST_NAME = 'Alignment';
. "$PSScriptRoot\Common.ps1"

# Generate the assembly
$Output = GenerateSetup;
$Instructions = (GetInstructions -Blacklist Memory,Branch);
if ($RandomOrder) { $Instructions = $Instructions | Sort-Object {Get-Random}; }

$TestNames = @();

[byte] $ID = 0;
foreach($Instr in $Instructions)
{
    $Output += GenerateTestStart $ID -Description $Instr.Name;
    $Output += @(
        '.balign 4',
        'c.nop',
        'PIN_ON_A',
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Aligned I1 Aligned"),
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Aligned I2 Misaligned"),
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Aligned I3 Aligned"),
        'PIN_OFF_A',
        '.balign 4',
        'c.nop',
        'c.nop',
        'PIN_ON_A',
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Misaligned I1 Misaligned"),
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Misaligned I2 Aligned"),
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16 -Name "$($Instr.Name) Test Misaligned I3 Misaligned"),
        'PIN_OFF_A'
    );
    $Output += GenerateTestEnd;

    $ID++;
    $TestNames += $Instr.Name;
}

#$LoadStoreInstructions = @(
#    @{},
#    @{}
#);
#foreach($LSInstr in $LoadStoreInstructions)
#{
#    $Output += GenerateTestStart $ID -Description $LSInstr.Name;
#    $Output += @(
#
#    );
#    $Output += GenerateTestEnd;
#
#    $ID++;
#    $TestNames += $LSInstr.Name;
#}

Write-Host "Generated tests: $([string]::Join([char]',',$TestNames))";

$OutputDir = Join-Path $PSScriptRoot './Generated/';
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory $OutputDir; }
Set-Content (Join-Path $OutputDir "$TEST_NAME.S") -Value $Output;

[string] $LACaptureCSV = Join-Path $PSScriptRoot "../Captures/$TEST_NAME.csv";
if (!$NoProgram)
{
    Write-Host 'Building and flashing program...';
    BuildTest $TEST_NAME;

    if(!$NoCapture -AND !$ManualCapture)
    {
        Write-Host 'Starting logic analyzer...';
        $ListenerProc = StartListener $LACaptureCSV;
    }

    Write-Host 'Starting the test program...';
    Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-s', '0x04', '0x444F');
}

if(!$NoCapture -AND !$ManualCapture)
{
    Write-Host 'Waiting for logic analyzer...';
    $ListenerProc.WaitForExit();
}

if (!$NoCapture)
{
    if($ManualCapture)
    {
        Write-Host 'Press any key once you have saved the CSV file.';
        if(!$NonInteractive) { [Console]::ReadKey() | Out-Null; }
    }
    Write-Host 'Parsing output...';
    $ParsedData = ParseCapture $LACaptureCSV;

    [string] $DataOutFile = Join-Path $PSScriptRoot '../Data/Alignment.csv';
    Write-Host "Saving test results to $DataOutFile";
    [StreamWriter] $OutputFile = [StreamWriter]::new($DataOutFile);
    $OutputFile.WriteLine('Test,CyclesAligned,CyclesMisaligned');
    [int] $DataIndex = 0;
    foreach($TestName in $TestNames)
    {
        $TestData = ReadSingleTest $ParsedData ([ref]$DataIndex);
        if ($TestData.Count -NE 5) { Write-Host "The data for test '$TestName' was $($TestData.Count) items long, expected 5."; continue; }
        if (($TestData[0].Bit -NE 0) -OR
            ($TestData[1].Bit -NE 1) -OR
            ($TestData[2].Bit -NE 0) -OR
            ($TestData[3].Bit -NE 1) -OR
            ($TestData[4].Bit -NE 0)) { Write-Host "Got bad data pattern for test '$TestName': $TestData"; continue; }
        
        $OutputFile.WriteLine("$TestName,$($TestData[1].CycleCount - 2),$($TestData[3].CycleCount - 2)");
    }
    $OutputFile.Close();
}
