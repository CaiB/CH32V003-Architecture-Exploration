# Generates two of every instruction, one aligned and one unaligned.
# This is used to determine if the alignment of any individual instruction matters, but does not check the relationship between alignments of multiple instructions.

[CmdletBinding()]
param (
    [Parameter()]
    [switch] $NoCapture,
    [switch] $ManualCapture
)

$ErrorActionPreference = 'Stop';
$TEST_NAME = 'Alignment';
. .\Common.ps1

# Generate the assembly
$Output = GenerateSetup;
$Instructions = (GetInstructions -Blacklist Memory,Branch);

$TestNames = @();

[byte] $ID = 0;
foreach($Instr in $Instructions)
{
    $Output += GenerateTestStart $ID -Description $Instr.Name;
    $Output += @(
        '.balign 4',
        'c.nop',
        'PIN_ON_A',
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16), # Aligned
        'PIN_OFF_A',
        '.balign 4',
        'c.nop',
        'c.nop',
        'PIN_ON_A',
        (FormatInstruction $Instr -Dest 'a3' -Src1 'a1' -Src2 'a2' -Immediate 16), # Misaligned
        'PIN_OFF_A'
    );
    $Output += GenerateTestEnd;

    $ID++;
    $TestNames += $Instr.Name;
}

$OutputDir = Join-Path $PSScriptRoot './Generated/';
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory $OutputDir; }
Set-Content (Join-Path $OutputDir "$TEST_NAME.S") -Value $Output;

Write-Host 'Building and flashing program...';
BuildTest $TEST_NAME;

[string] $LACaptureCSV = Join-Path $PSScriptRoot "../Captures/$TEST_NAME.csv";
if(!$NoCapture -AND !$ManualCapture)
{
    Write-Host 'Starting logic analyzer...';
    $ListenerProc = StartListener $LACaptureCSV;
}

Write-Host 'Starting the test program...';
Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-s', '0x04', '0x444F');

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
        [Console]::ReadKey() | Out-Null;
    }
    Write-Host 'Parsing output...';
    $ParsedData = ParseCapture $LACaptureCSV;

    [int] $DataIndex = 0;
    $TestData = ReadSingleTest $ParsedData ([ref]$DataIndex);
    Write-Host $TestData;
}