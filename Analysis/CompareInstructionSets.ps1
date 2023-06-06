using namespace System.IO;
using namespace System.Drawing;
using namespace System.Windows;
using namespace System.Text.RegularExpressions;

$ErrorActionPreference = 'Stop';
[string[]] $ExpectedData = [string[]]::new(65536);
[PSCustomObject[]] $ActualData = [PSCustomObject[]]::new(65536);

$ExpectedInput = Get-Content (Join-Path $PSScriptRoot '../Analysis/RVInstructionListing/rv32c-instructions.csv');
$ActualInput = Get-Content (Join-Path $PSScriptRoot '../Data/CompressedOpcodesReprocess.csv');

foreach ($Line in $ExpectedInput)
{
    if (($Line[0] -LT [char]'0') -OR ($Line[0] -GT [char]'9')) { continue; } # This line doesn't start with a number (e.g. header)
    [int] $CommaIndex = $Line.IndexOf([char]',');
    if ($CommaIndex -LE 0) { throw "In expected input file, line '$Line' could not be parsed."; }
    [uint] $Instruction = [int]::Parse($Line.Substring(0, $CommaIndex));
    [string] $InstructionName = $Line.Substring($CommaIndex + 1);
    $ExpectedData[$Instruction] = $InstructionName;
}

[Regex] $ActualInputLineParser = [Regex]::new('^(\d+),([\d\.]+),(\d+),(\d+)$', [RegexOptions]::Compiled);
foreach ($Line in $ActualInput)
{
    if (($Line[0] -LT [char]'0') -OR ($Line[0] -GT [char]'9')) { continue; } # This line doesn't start with a number (e.g. header)
    [Match] $ParsedInput = $ActualInputLineParser.Match($Line);
    if ($ParsedInput.Success)
    {
        [int] $Instruction = [int]::Parse($ParsedInput.Groups[1]);
        [float] $CyclesTaken = [float]::Parse($ParsedInput.Groups[2]); # This is fractional if it's a processor reset event.
        [int] $ClockStop = [int]::Parse($ParsedInput.Groups[3]);
        [int] $LaterCyclesTaken = [int]::Parse($ParsedInput.Groups[4]);
        $ActualData[$Instruction] = [PSCustomObject]@{ CyclesTaken = $CyclesTaken; ClockStop = $ClockStop; LaterCyclesTaken = $LaterCyclesTaken };
    }
    else { throw "In actual input file, line '$Line' could not be parsed."; }
}

[int] $COLUMNS = 256;
[int] $ROWS = [Math]::Ceiling(0x10000 / $COLUMNS);
[string] $OutputPath = $(Join-Path $PSScriptRoot '../Data/CompareInstructionSets.csv');
[StreamWriter] $OutputFile = [StreamWriter]::new($OutputPath);

# https://superuser.com/a/704291 <- Now that's what I call janky

$OutputFile.Write(',');
for ($Col = 0; $Col -LT $COLUMNS; $Col++) { $OutputFile.Write("`t{0:X2}," -F $Col); }
$OutputFile.WriteLine();

for ($Instr = 0; $Instr -LT $ExpectedData.Length; $Instr++)
{
    if ($Instr % $COLUMNS -EQ 0)
    {
        if ($Instr -NE 0) { $OutputFile.WriteLine(); }
        $OutputFile.Write("`t{0:X4}," -F $Instr);
    }

    # This instruction cannot exist.
    if (($Instr -BAND 3) -EQ 3) { $OutputFile.Write('X,'); continue; }

    if ($numm -EQ $ActualData[$Instr]) { [float] $CyclesTaken = 0; }
    else { [float] $CyclesTaken = $ActualData[$Instr].CyclesTaken - 2; } # Subtract 2 because that's how long it takes for the GPIO off instruction after the actual test instruction

    # This instruction caused the CPU to reset.
    if ($ActualData[$Instr].ClockStop -GT 1)
    {
        $RSTCycles = $ActualData[$Instr].CyclesTaken;
        if (($RSTCycles -GT 6) -AND ($RSTCycles -LT 7)) { $OutputFile.Write('RST Shrt,'); }
        elseif (($RSTCycles -GT 9) -AND ($RSTCycles -LT 10)) { $OutputFile.Write('RST Med,'); }
        elseif (($RSTCycles -GT 94) -AND ($RSTCycles -LT 96)) { $OutputFile.Write('RST Long,'); }
        else { $OutputFile.Write('RST Unk {0:F1},', $RSTCycles); }
        continue;
    }

    # This instruction is part of the expected set. Choose one:
    # Write-Host "$Instr -> $($ExpectedData[$Instr])";
    # if ($ExpectedData[$Instr] -NE 'UNK') { $OutputFile.Write('Exist,'); continue; }
    # if ($ExpectedData[$Instr] -NE 'UNK') { $OutputFile.Write("Exist_$($ExpectedData[$Instr]),"); continue; } # Output the instruction name
    if ($ExpectedData[$Instr] -NE 'UNK') # Output how long it took, or just the name if no data available
    {
        if ($null -EQ $ActualData[$Instr]) { $OutputFile.Write("$($ExpectedData[$Instr]),"); continue; }
        else { $OutputFile.Write("Ex $CyclesTaken,"); continue; }
    }

    # This instruction doesn't exist, and it was not tested.
    if ($null -EQ $ActualData[$Instr]) { $OutputFile.Write('NoTest,'); continue; }

    # This instruction doesn't exist, and caused the pin to no longer respond.
    if ($ActualData[$Instr].CyclesTaken -GT 600) # This may need to be tuned for capture times shorter than 20us.
    {
        $OutputFile.Write('Unresp,');
        continue;
    }

    # This instruction worked.
    $OutputFile.Write("New $CyclesTaken,"); 
}

$OutputFile.Close();

[int] $LegendRowIndex = 3;
function AddConditionalExpr # Color format is 0x00BBGGRR
{
    param ($Sheet, $CellRange, $Expression, $Color, $Description, [switch]$PassThru);
    $NewFormatCondition = $CellRange.FormatConditions.Add(2, 0, $Expression);
    $NewFormatCondition.Interior.Color = $Color;
    $Sheet.Cells.Item($LegendRowIndex, $COLUMNS + 4).Interior.Color = $Color;
    $Sheet.Cells.Item($LegendRowIndex, $COLUMNS + 5) = $Description;
    $script:LegendRowIndex++;
    if($PassThru) { return $NewFormatCondition; }
}

$ExcelWBPath = (Join-Path $PSScriptRoot '../Analysis/CompareInstructionSets.xlsx');
if (Test-Path $ExcelWBPath) { Remove-Item $ExcelWBPath; }
$Excel = New-Object -COMObject 'Excel.Application';
$Excel.Workbooks.Open($OutputPath).SaveAs($ExcelWBPath, 51);
$Excel.Visible = $true;

$Sheet = $Excel.ActiveSheet;
$Sheet.Rows.Item(1).Font.Bold = $true;
$Sheet.Columns.Item(1).Font.Bold = $true;

$TopLeft = $Sheet.Cells.Item(2, 2); # Excel is one-indexed
$BottomRight = $Sheet.Cells.Item($ROWS + 2, $COLUMNS + 2);
$DataRange = $Sheet.Range($TopLeft, $BottomRight);

[void] $($Sheet.Range($Sheet.Cells.Item(1, 1), $BottomRight).Columns.AutoFit());

# For some reason, the first one we add CANNOT be added via a PowerShell function. There's some bizarre voodoo going on here
$AAAWHYEXCEL = $DataRange.FormatConditions.Add(2, 0, '=(B2="X")');
$AAAWHYEXCEL.Interior.Color = 0x7F7F7F;
$AAAWHYEXCEL.Font.ColorIndex = 16;

AddConditionalExpr $Sheet $DataRange '=(B2="Unresp")' 0x55BBDD 'This instruction isn''t expected to exist, and running it timed out the pin';
AddConditionalExpr $Sheet $DataRange '=(B2="NoTest")' 0x6688DD 'This instruction isn''t expected to exist, and was skipped in testing';
AddConditionalExpr $Sheet $DataRange '=(Left(B2,2)="c.")' 0xFFFFFF 'This instruction was expected to exist, but was skipped in testing';

AddConditionalExpr $Sheet $DataRange '=(B2="Ex 1")' 0x336633 'This instruction was expected to exist, and took 1 cycle to execute';
AddConditionalExpr $Sheet $DataRange '=(B2="Ex 2")' 0x448844 'This instruction was expected to exist, and took 2 cycles to execute';
AddConditionalExpr $Sheet $DataRange '=(B2="Ex 3")' 0x77AA55 'This instruction was expected to exist, and took 3 cycles to execute';

AddConditionalExpr $Sheet $DataRange '=(AND(LEFT(B2, 3)="Ex ", NUMBERVALUE(RIGHT(B2, LEN(B2) - 3)) > 3, NUMBERVALUE(RIGHT(B2, LEN(B2) - 3)) < 100))' 0xBBDD88 'This instruction was expected to exist, but took more than 3 cycles to execute (likely random branches)';
AddConditionalExpr $Sheet $DataRange '=(AND(LEFT(B2, 3)="Ex ", NUMBERVALUE(RIGHT(B2, LEN(B2) - 3)) > 99, NUMBERVALUE(RIGHT(B2, LEN(B2) - 3)) < 500))' 0x662211 'This instruction was expected to exist, but executing it caused the chip to completey stop responding until power cycled';
AddConditionalExpr $Sheet $DataRange '=(AND(LEFT(B2, 3)="Ex ", NUMBERVALUE(RIGHT(B2, LEN(B2) - 3)) > 499))' 0xFF9988 'This instruction was expected to exist, but did not complete, or overwrote a critical register';

AddConditionalExpr $Sheet $DataRange '=(B2="New 1")' 0xFF55AA 'This instruction is new, and took 1 cycle to execute';
AddConditionalExpr $Sheet $DataRange '=(B2="New 2")' 0xDD66BB 'This instruction is new, and took 2 cycles to execute';
AddConditionalExpr $Sheet $DataRange '=(B2="New 3")' 0xDD66CC 'This instruction is new, and took 3 cycles to execute';

AddConditionalExpr $Sheet $DataRange '=(AND(LEFT(B2, 4)="New ", NUMBERVALUE(RIGHT(B2, LEN(B2) - 4)) > 3, NUMBERVALUE(RIGHT(B2, LEN(B2) - 4)) < 100))' 0xDD55EE 'This instruction is new, but took more than 3 cycles to execute (likely random branches)';
AddConditionalExpr $Sheet $DataRange '=(AND(LEFT(B2, 4)="New ", NUMBERVALUE(RIGHT(B2, LEN(B2) - 4)) > 99, NUMBERVALUE(RIGHT(B2, LEN(B2) - 4)) < 500))' 0xBB55FF 'This instruction is new, but executing it caused the chip to completey stop responding until power cycled';

AddConditionalExpr $Sheet $DataRange '=(B2="RST Shrt")' 0x2233DD 'This instruction caused the CPU to reset, missing about 6.5 cycles';
AddConditionalExpr $Sheet $DataRange '=(B2="RST Med")' 0x2222AA 'This instruction caused the CPU to reset, missing about 9.5 cycles';
AddConditionalExpr $Sheet $DataRange '=(B2="RST Long")' 0x111177 'This instruction caused the CPU to reset, missing about 95 cycles';

[void] $($TopLeft.Select());
$Excel.ActiveWindow.FreezePanes = $true;

$Excel.ActiveWorkbook.Save();

