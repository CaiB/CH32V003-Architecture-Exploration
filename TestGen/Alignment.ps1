# Generates two of every instruction, one aligned and one unaligned.
# This is used to determine if the alignment of any individual instruction matters, but does not check the relationship between alignments of multiple instructions.

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('DSViewAHK', 'SigrokCLI', 'Manual', 'None')]
    [string] $CaptureMethod, # How should data be captured from the logic analyzer?
    [switch] $Clean, # Removes all intermediate files before starting
    [switch] $NoProgram, # Does everything except compiling or programming the device
    [switch] $RandomOrder, # Shuffles the order of the tests to minimize the impact of boundary conditions
    [switch] $MisalignFirst # Whether to execute misaligned,aligned (true) or Aligned,Misaligned (false)
)

# Cleanup and basics
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

# Set up paths for all intermediate files, delete them if -Clean is selected, and create folders for them if they don't exist.
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

## Generate the assembly
# Get the list of instructions that we want to test, and randomize them if -RandomOrder
$Output = GenerateSetup;
$Instructions = (GetInstructions -Blacklist Memory,Branch);
if ($RandomOrder) { $Instructions = $Instructions | Sort-Object {Get-Random}; }

# Choose pattern lengths, each instruction will be configured in every option (note the flash is small)
$TestInformation = $Instructions | ForEach-Object {
    $Imm = 16;
    if ($_.Name -EQ 'lui') { $Imm = 775; } # If the immediate is too small for lui, it will silently be converted to c.lui

    #[PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x3"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = $Imm; Count = 3 },
    [PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x5"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = $Imm; Count = 5 },
    #[PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x7"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = $Imm; Count = 7 },
    [PSCustomObject]@{ Instruction = $_; Name = "$($_.Name) x9"; Dest = 'a3'; Src1 = 'a1'; Src2 = 'a2'; Immediate = $Imm; Count = 9 }
};

# Generate the actual test instructions for each
[byte] $ID = 0;
foreach($TestEntry in $TestInformation)
{   
    $AlignedTest = @(
        '.balign 4',
        'c.nop',
        'PIN_ON_A'
    );
    for ($i = 0; $i -LT $TestEntry.Count; $i++) # Aligned
    {
        $AlignedTest += (FormatInstruction -InstrObj $TestEntry.Instruction `
            -Dest $TestEntry.Dest -Src1 $TestEntry.Src1 -Src2 $TestEntry.Src2 -Immediate $TestEntry.Immediate `
            -Name "$($TestEntry.Name) Test Aligned I$i ($(if($i % 2 -EQ 0) { 'A' } else { 'Misa' })ligned if comp)");
    }
    $AlignedTest += 'PIN_OFF_A';

    $MisalignedTest = @(
        '.balign 4',
        'c.nop',
        'c.nop',
        'PIN_ON_A'
    );
    for ($i = 0; $i -LT $TestEntry.Count; $i++) # Misaligned
    {
        $MisalignedTest += (FormatInstruction -InstrObj $TestEntry.Instruction `
            -Dest $TestEntry.Dest -Src1 $TestEntry.Src1 -Src2 $TestEntry.Src2 -Immediate $TestEntry.Immediate `
            -Name "$($TestEntry.Name) Test Misligned I$i ($(if($i % 2 -EQ 0) { 'Misa' } else { 'A' })ligned if comp)");
    }
    $MisalignedTest += 'PIN_OFF_A'

    $Output += GenerateTestStart $ID -Description $Instr.Name; # Test ID signal
    if ($MisalignFirst)
    {
        $Output += $MisalignedTest;
        $Output += $AlignedTest;
    }
    else
    {
        $Output += $AlignedTest;
        $Output += $MisalignedTest;
    }
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

Write-Host "Generated tests: $([string]::Join([char]',', $($TestInformation | ForEach-Object {$_.Name}))))";
Set-Content $GeneratedASM -Value $Output;

if (!$NoProgram) # This compiles the C, along with the generated assembly, and programs the CH32V003 with the program
{
    Write-Host 'Building and flashing program...';
    BuildTest $TEST_NAME;
} # The chip is now waiting for our start signal before beginning the test

switch ($CaptureMethod)
{
    'None' { break; } # Won't do capture, will just read previously captured results
    'Manual' { break; } # Assume the capture has been started
    'DSViewAHK' {
        Write-Host 'Starting logic analyzer via AHK on DSView...';
        StartAHKScript $(Join-Path $PSScriptRoot '/DSView/StartCapture.ahk');
    }
    'SigrokCLI' {
        Write-Host 'Starting logic analyzer via Sigrok...';
        $SigrokProc = StartListenerSigrok $LACaptureCSV;
    }
}

# This actually triggers the chip to start the tests
Write-Host 'Starting the test program...';
Start-Process -NoNewWindow -Wait "$script:MINICHLINK/minichlink" -ArgumentList @('-s', '0x04', '0x444F');

switch ($CaptureMethod)
{
    'None' { return; } # Not doing capture, will just read previously captured results
    'Manual' { # Wait for the user to export data from logic analyzer
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

# Transform the raw signal analyzer data into cycle count data
Write-Host 'Parsing output...';
[string] $PostprocDir = $(Join-Path $PSScriptRoot '../Captures/Postprocessed/');
if (!(Test-Path $PostprocDir)) { New-Item -Type Directory $PostprocDir; }
$ParsedData = ParseCapture $LACaptureCSV $ProcessedCSV;

# Read out each test result from the cycle counts, and save the final data into a new CSV
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
    
    if ($MisalignFirst) { $OutputFile.WriteLine("$($TestEntry.Name),$($TestData[3].CycleCount - 2),$($TestData[1].CycleCount - 2)"); }
    else { $OutputFile.WriteLine("$($TestEntry.Name),$($TestData[1].CycleCount - 2),$($TestData[3].CycleCount - 2)"); }
}
$OutputFile.Close();
