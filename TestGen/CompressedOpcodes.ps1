# Generates a framework to brute force test every 16b (compressed) instruction, then modifies and runs those tests on the chip
# The search space is 15.5b (49152 possibilities), as all compressed instructions must end with 00, 01, or 10 (not 11) in bits [1:0]

[CmdletBinding()]
param (
    [Parameter()]
    [switch] $Clean, # Removes all intermediate files before starting
    [switch] $NoProgram, # Does everything except compiling or programming the device
    [ValidateSet('DSViewAHK', 'SigrokCLI', 'Manual', 'None')]
    [string] $CaptureMethod # How should data be captured from the logic analyzer?
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

$TEST_NAME = 'CompressedOpcodes';
. "$PSScriptRoot\Common.ps1"

# Set up paths for all intermediate files, delete them if -Clean is selected, and create folders for them if they don't exist.
[string] $GeneratedASM = Join-Path $PSScriptRoot "/Generated/$TEST_NAME.S";
[string] $LocationMapBranch = Join-Path $PSScriptRoot "/Generated/${TEST_NAME}_BranchLocs.txt"
[string] $LocationMapTest = Join-Path $PSScriptRoot "/Generated/${TEST_NAME}_TestLocs.txt"
[string] $TemplateBIN = Join-Path $PSScriptRoot "/Generated/${TEST_NAME}_Template.bin";
[string] $LACaptureCSV = Join-Path $PSScriptRoot "../Captures/$TEST_NAME.csv";
[string] $ProcessedCSV = Join-Path $PSScriptRoot "../Captures/Postprocessed/$TEST_NAME.csv";
[string] $DataOutFile = Join-Path $PSScriptRoot "../Data/$TEST_NAME.csv";
$AllFiles = @($GeneratedASM, $LocationMapBranch, $LocationMapTest, $TemplateBIN, $LACaptureCSV, $ProcessedCSV, $DataOutFile);
if ($Clean) { Remove-Item $AllFiles -ErrorAction SilentlyContinue; }
$AllFiles | Foreach-Object {
    [string] $DirName = [Path]::GetDirectoryName($_);
    if (!(Test-Path $DirName)) { New-Item -Type Directory $DirName | Out-Null; }
}

## Generate the template assembly
$Output = GenerateSetup;
#$Output += (FormatInstruction -Instr 'c.addi' -Dest 't1' -Immediate 21 -Name "BranchSlot_0") # HEX 0355
$Output += GenerateTestStart 0x69 -Description $Instr.Name; # Test ID signal
$Output += @(
    '.balign 4',
    'c.nop',
    'PIN_ON_A',
    (FormatInstruction -Instr 'c.addi' -Dest 't1' -Immediate 19 -Name "TestSlot_0") # HEX 034D
    'PIN_OFF_A',
    'c.nop',
    'c.nop',
    'PIN_ON_A'
    'PIN_OFF_A'
);
$Output += GenerateTestEnd;

[UInt16] $BRANCH_MARKER_INSTR = 0x0355;
[UInt16] $TEST_MARKER_INSTR = 0x034D;

Set-Content $GeneratedASM -Value $Output;

Write-Host 'Building template program...';
BuildTest $TEST_NAME -NoFlash;

Write-Host 'Exporting marker locations...';
#$BranchMarkers = ExportMarkerLocations -LSTFile $(Join-Path $PSScriptRoot "${TEST_NAME}.lst") -OutputFile $LocationMapBranch -MarkerRegex 'BranchSlot_(\d+)' -CheckOpcode $BRANCH_MARKER_INSTR;
$TestMarkers =   ExportMarkerLocations -LSTFile $(Join-Path $PSScriptRoot "${TEST_NAME}.lst") -OutputFile $LocationMapTest -MarkerRegex 'TestSlot_(\d+)' -CheckOpcode $TEST_MARKER_INSTR;

Move-Item $(Join-Path $PSScriptRoot "${TEST_NAME}.bin") $TemplateBIN -Force;

[StreamWriter] $OutputFile = [StreamWriter]::new($DataOutFile, $true);
$OutputFile.WriteLine('InstrCode,CyclesTaken,ClockStop,LaterCyclesTaken,{0}' -F (Get-Date).ToString('yyyy-MM-dd,HH:mm:ss'));
Write-Host "Saving test results to $DataOutFile";

[string] $BackupFolder = $(Join-Path $PSScriptRoot "../Data/${TEST_NAME}_ALL/");
if (!(Test-Path $BackupFolder)) { New-Item -ItemType Directory $BackupFolder | Out-Null; }

[System.Diagnostics.Stopwatch] $LoopTimer = [System.Diagnostics.Stopwatch]::new();
[float] $AvgTimeTaken = 0;
[int] $TestsFinished = 0;

try
{
    [UInt16] $START_INSTR = 0x0C9C;
    for ($InstrCode = $START_INSTR; $InstrCode -LT 0xFFFF; $InstrCode++)
    {
        if (($InstrCode -BAND 0x0003) -EQ 0x0003) { continue; } # This isn't a valid compressed instruction
        try
        {
            $LoopTimer.Restart();
            ReplaceInstruction $TemplateBIN -OutputFile $(Join-Path $PSScriptRoot "${TEST_NAME}.bin") -Compressed -Location $TestMarkers[0] -Expect $TEST_MARKER_INSTR -New $InstrCode;

            Write-Host 'Flashing program variation...';
            BuildTest $TEST_NAME;
            # The chip is now waiting for our start signal before beginning the test

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

            [string] $ThisBackup = Join-Path $BackupFolder $("/{0:X2}/{1:X2}" -F (($InstrCode -SHR 8) -BAND 0xFF), ($InstrCode -BAND 0xFF));
            if (!(Test-Path $ThisBackup)) { New-Item -ItemType Directory $ThisBackup | Out-Null; }
            Copy-Item $LACaptureCSV $(Join-Path $ThisBackup '/RawCapture.csv') -Force;

            # Transform the raw signal analyzer data into cycle count data
            Write-Host 'Parsing output...';
            [string] $PostprocDir = $(Join-Path $PSScriptRoot '../Captures/Postprocessed/');
            if (!(Test-Path $PostprocDir)) { New-Item -Type Directory $PostprocDir; }
            $ParsedData = ParseCapture $LACaptureCSV $ProcessedCSV;

            Copy-Item $ProcessedCSV $(Join-Path $ThisBackup '/ProcessedCapture.csv') -Force;

            # Read out this test result from the cycle counts, and add that to the output CSV
            # InstrCode,CyclesTaken,ClockStop,LaterCyclesTaken
            [int] $DataIndex = 0;
            ReadSingleTest $ParsedData ([ref]$DataIndex) -SeekOnly;

            [int] $RemainingData = $ParsedData.Count - $DataIndex;
            Write-Host "$RemainingData transitions found.";

            [int] $ClockStop = 0;
            for($i = $DataIndex; $i -LT $ParsedData.Count; $i++)
            {
                if ($ParsedData[$i].Bit -EQ -1) { $ClockStop = $ParsedData[$i].CycleCount; break; }
            }

            [string] $OutputLine = '';
            if ($RemainingData -LT 2) { $OutputLine = "$InstrCode,0,$ClockStop,0"; }
            elseif ($RemainingData -EQ 2) { $OutputLine = "$InstrCode,$($ParsedData[$DataIndex + 1].CycleCount),$ClockStop,0"; } # |__|^^^^^^^^^^^^
            elseif ($RemainingData -EQ 3) { $OutputLine = "$InstrCode,$($ParsedData[$DataIndex + 1].CycleCount),$ClockStop,0"; } # |__|^^|_________
            elseif ($RemainingData -EQ 4) { $OutputLine = "$InstrCode,$($ParsedData[$DataIndex + 1].CycleCount),$ClockStop,$($ParsedData[$DataIndex + 3].CycleCount)"; } # |__|^^|__|^^^^^^
            elseif ($RemainingData -GE 5) { $OutputLine = "$InstrCode,$($ParsedData[$DataIndex + 1].CycleCount),$ClockStop,$($ParsedData[$DataIndex + 3].CycleCount)"; } # |__|^^|__|^^|____

            $OutputFile.WriteLine($OutputLine);
            $OutputFile.Flush();
            $TestsFinished++;

            Write-Host $('====== Finished 0x{0:X4} ({2:F2}%), got {1} ======' -F $InstrCode, $OutputLine, ($InstrCode / 65536.0 * 100));
            $LoopTimer.Stop();
            if ($AvgTimeTaken -EQ 0) { $AvgTimeTaken = $LoopTimer.ElapsedMilliseconds; }
            else { $AvgTimeTaken = ($AvgTimeTaken * 0.95) + (0.05 * $LoopTimer.ElapsedMilliseconds); }
            [int] $InstructionsLeft = ((65536 - $START_INSTR) * 0.75 - $TestsFinished);
            Write-Host "Left: $InstructionsLeft";
            [TimeSpan] $ETA = [TimeSpan]::FromSeconds($InstructionsLeft * $AvgTimeTaken / 1000);
            Write-Host $('====== Took {0:F0}ms (avg {1:F0}ms), ETA: {3}h:{2} ======' -F $LoopTimer.ElapsedMilliseconds, $AvgTimeTaken, $ETA.ToString('mm\m\:ss\s'), [Math]::Floor($ETA.TotalHours));
        }
        catch
        {
            Write-Error $("Failed to process instruction 0x{0:X4}`n{1}" -F $InstrCode, $_);
        }
    }
}
finally
{
    $OutputFile.Close();
}

