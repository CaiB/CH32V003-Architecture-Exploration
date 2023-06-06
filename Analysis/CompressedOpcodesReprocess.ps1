# Takes the output from CompressedOpcodes, and reprocesses all of the important data out of the individual logic analyzer captures into a single CSV.

[CmdletBinding()]
param (
    [Parameter()]
    [switch] $Append,
    [switch] $MultiColumn,
    [switch] $ReparseExisting,
    [string] $CapturesPath = $(Join-Path $PSScriptRoot "../Data/CompressedOpcodes_ALL/")
)

$TEST_NAME = 'CompressedOpcodesReprocess';
. "$PSScriptRoot\Common.ps1"

[UInt16] $START_INSTR = 0x0000;
[UInt16] $END_INSTR = 0xFFFF;

[string] $DataOutFile = Join-Path $PSScriptRoot "../Data/$TEST_NAME.csv";

[StreamWriter] $OutputFile = [StreamWriter]::new($DataOutFile, $Append);
$OutputFile.WriteLine('InstructionDecimal,CyclesTaken,ClockStop,NextBlipCycles');

try
{
    for ($InstrCode = $START_INSTR; $InstrCode -LT $END_INSTR; $InstrCode++)
    {
        if (($InstrCode -BAND 0x0003) -EQ 0x0003) { continue; } # This isn't a valid compressed instruction

        [string] $InputDir = Join-Path $CapturesPath $("/{0:X2}/{1:X2}" -F (($InstrCode -SHR 8) -BAND 0xFF), ($InstrCode -BAND 0xFF));
        [string] $InputFileName = Join-Path $InputDir '/RawCapture.csv';
        [string] $ProcessedCSV = Join-Path $InputDir '/ProcessedCapture.csv';

        if (!(Test-Path $InputFileName)) { Write-Host $('Data missing for instruction 0x{0:X4}' -F $InstrCode); continue; }

        [bool] $ProcessedFileExists = (Test-Path $ProcessedCSV);
        if (!$ProcessedFileExists -OR $ReparseExisting)
        {
            if(!$ProcessedFileExists) { Write-Host "File $ProcessedCSV did not yet exist!"; }
            $ParsedData = ParseCapture $InputFileName $ProcessedCSV;
        }
        else { $ParsedData = ParseCapture $InputFileName $ProcessedCSV -NoOutFile; }

        # Write-Host $ParsedData;

        [int] $DataIndex = 0;
        ReadSingleTest $ParsedData ([ref]$DataIndex) -SeekOnly;

        [int] $RemainingData = $ParsedData.Count - $DataIndex;
        # Write-Host "$RemainingData transitions found.";

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
        if (($InstrCode -BAND 0xFF) -EQ 0)
        {
            Write-Host $('At 0x{0:X4}' -F $InstrCode);
            $OutputFile.Flush();
        }
    }
}
finally
{
    $OutputFile.Close();
}