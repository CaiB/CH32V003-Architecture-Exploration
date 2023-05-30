# Generates two of every instruction, one aligned and one unaligned.
# This is used to determine if the alignment of any individual instruction matters, but does not check the relationship between alignments of multiple instructions.

[CmdletBinding()]
param (
    [Parameter()]
    [switch] $Clean,
    [switch] $NoProgram,
    [switch] $RandomOrder,
    [ValidateSet('DSViewAHK', 'SigrokCLI', 'Manual', 'None')]
    [string] $CaptureMethod
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

[string] $GeneratedASM = Join-Path $PSScriptRoot "/Generated/$TEST_NAME.S";
[string] $LACaptureCSV = Join-Path $PSScriptRoot "../Captures/$TEST_NAME.csv";
[string] $ProcessedCSV = Join-Path $PSScriptRoot "../Captures/Postprocessed/$TEST_NAME.csv";
[string] $DataOutFile = Join-Path $PSScriptRoot "../Data/$TEST_NAME.csv";
$AllFiles = @($GeneratedASM, $LACaptureCSV, $ProcessedCSV, $DataOutFile);
if ($Clean) { Remove-Item $AllFiles -ErrorAction SilentlyContinue; }
$AllFiles | Foreach-Object {
    [string] $DirName = [Path]::GetDirectoryName($_);
    if (!(Test-Path $DirName)) { New-Item -Type Directory $DirName; }
}

# Generate the assembly
$Output = GenerateSetup;
$Instructions = (GetInstructions -Blacklist Memory,Branch);
if ($RandomOrder) { $Instructions = $Instructions | Sort-Object {Get-Random}; }

$TestInformation = $Instructions | ForEach-Object {
    [PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x3"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = 16; Count = 3 },
    #[PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x5"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = 16; Count = 5 },
    [PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x7"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = 16; Count = 7 }
};

[byte] $ID = 0;
foreach($TestEntry in $TestInformation)
{
    $Output += GenerateTestStart $ID -Description $Instr.Name;
    $Output += @(
        '.balign 4',
        'c.nop',
        'PIN_ON_A'
    );
    for ($i = 0; $i -LT $TestEntry.Count; $i++)
    {
        $Output += (FormatInstruction -InstrObj $TestEntry.Instruction -Dest $TestEntry.Dest -Src1 $TestEntry.Src1 -Src2 $TestEntry.Src2 -Immediate $TestEntry.Immediate -Name "$($TestEntry.Name) Test Aligned I$i ($(if($i % 2 -EQ 0) { 'A' } else { 'Misa' })ligned)");
    }
    $Output += @(
        'PIN_OFF_A',
        '.balign 4',
        'c.nop',
        'c.nop',
        'PIN_ON_A'
    );
    for ($i = 0; $i -LT $TestEntry.Count; $i++)
    {
        $Output += (FormatInstruction -InstrObj $TestEntry.Instruction -Dest $TestEntry.Dest -Src1 $TestEntry.Src1 -Src2 $TestEntry.Src2 -Immediate $TestEntry.Immediate -Name "$($TestEntry.Name) Test Misligned I$i ($(if($i % 2 -EQ 0) { 'Misa' } else { 'A' })ligned)");
    }
    $Output += 'PIN_OFF_A'
    $Output += GenerateTestEnd;

    $ID++;
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
#}

Write-Host "Generated tests: $([string]::Join([char]',',$($TestInformation | ForEach-Object {$_.Name}))))";

Set-Content $GeneratedASM -Value $Output;

if (!$NoProgram)
{
    Write-Host 'Building and flashing program...';
    BuildTest $TEST_NAME;
}


switch ($CaptureMethod)
{
    'None' { break; }
    'Manual' { break; }
    'DSViewAHK' {
        Write-Host 'Starting logic analyzer via AHK on DSView...';
        StartAHKScript $(Join-Path $PSScriptRoot '/DSView/StartCapture.ahk');
    }
    'SigrokCLI' {
        Write-Host 'Starting logic analyzer via Sigrok...';
        $SigrokProc = StartListenerSigrok $LACaptureCSV;
    }
}

Write-Host 'Starting the test program...';
Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-s', '0x04', '0x444F');

switch ($CaptureMethod)
{
    'None' { return; }
    'Manual' {
        Write-Host 'Press any key once you have saved the CSV file.';
        [Console]::ReadKey() | Out-Null;
    }
    'DSViewAHK' {
        Write-Host 'Exporting logic analyzer data via AHK on DSView...';
        StartAHKScript $(Join-Path $PSScriptRoot '/DSView/ExportCapture.ahk') @($([Path]::GetDirectoryName($LACaptureCSV)), $([Path]::GetFileName($LACaptureCSV)));
    }
    'SigrokCLI' {
        Write-Host 'Waiting for logic analyzer...';
        $SigrokProc.WaitForExit();
    }
}

Write-Host 'Parsing output...';
[string] $PostprocDir = $(Join-Path $PSScriptRoot '../Captures/Postprocessed/');
if (!(Test-Path $PostprocDir)) { New-Item -Type Directory $PostprocDir; }
$ParsedData = ParseCapture $LACaptureCSV $ProcessedCSV;

Write-Host "Saving test results to $DataOutFile";
[StreamWriter] $OutputFile = [StreamWriter]::new($DataOutFile);
$OutputFile.WriteLine('Test,CyclesAligned,CyclesMisaligned');
[int] $DataIndex = 0;
foreach($TestEntry in $TestInformation)
{
    $TestData = ReadSingleTest $ParsedData ([ref]$DataIndex);
    if ($TestData.Count -NE 5) { Write-Host "The data for test '$($TestEntry.Name)' was $($TestData.Count) items long, expected 5."; continue; }
    if (($TestData[0].Bit -NE 0) -OR
        ($TestData[1].Bit -NE 1) -OR
        ($TestData[2].Bit -NE 0) -OR
        ($TestData[3].Bit -NE 1) -OR
        ($TestData[4].Bit -NE 0)) { Write-Host "Got bad data pattern for test '$($TestEntry.Name)': $TestData"; continue; }
    
    $OutputFile.WriteLine("$($TestEntry.Name),$($TestData[1].CycleCount - 2),$($TestData[3].CycleCount - 2)");
}
$OutputFile.Close();
