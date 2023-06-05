using namespace System.Collections.Generic;
using namespace System.IO;
using namespace System;

# Magic, IDK
function Flatten($Nest) { ,@($Nest | % { if($null -NE $_) {$_} }); }

function GenerateSetup
{
    return @(
        '#define ASSEMBLER',
        '#include "ch32v003fun.h"',
        '#include "../Firmware/Firmware.h"',
        '#define BSHR_OFFSET 16',
        '#define INDR_OFFSET 8',
        '#define SYSTICK_CNT 0xE000F008',
        '',
        '#define PIN_OFF_A sw a1, BSHR_OFFSET(a0)',
        '#define PIN_ON_A sw a2, BSHR_OFFSET(a0)',
        '',
        '.global RunTests',
        'RunTests:',
        '// Prep',
        'la      a0, GPIOD_BASE',
        'li      a1, 1 << (16 + OUT_PIN_A) // A off *KEEP THIS*',
        'li      a2, 1 << OUT_PIN_A // A on *KEEP THIS*',
        'PIN_OFF_A',
        'nop; nop; nop; nop; // x4'
    );
}

function GenerateTestStart
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [byte] $ID,
        [Parameter(Mandatory = $false)]
        [string] $Description = ''
    )
    if ($Description) { $Description = " - $Description"; }

    $Output = @(
        '',
        ('// Test start {0} (0x{0:X2}){1}' -F $ID, $Description),
        '.balign 4',
        'PIN_ON_A',
        'nop; nop; nop; nop; nop; nop; nop; nop; // x8',
        'PIN_OFF_A'
    );

    for ($i = 7; $i -GE 0; $i--)
    {
        [int] $ThisBit = ($ID -SHR $i) -BAND 1;
        if ($ThisBit -EQ 0) { $Output += 'PIN_OFF_A'; }
        else { $Output += 'PIN_ON_A'; }
    }

    $Output += @(
        'PIN_OFF_A',
        'PIN_ON_A',
        'nop; nop; nop; nop; nop; nop; nop; nop; // x8',
        'PIN_OFF_A'
    );

    return $Output;
}

function GenerateTestEnd
{
    return @(
        'nop; nop; nop; nop; // x4',
        'PIN_ON_A',
        'nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; // x18',
        'PIN_OFF_A',
        '// Test end'
    );
}

[Flags()]
enum InstructionType
{
    Compressed = 1
    Immediate = 2
    Memory = 4
    Branch = 8
    TwoRegisterIn = 16
}

# TODO: Add parameter validation
$script:INSTRUCTION_SET = @(
    [PSCustomObject]@{ Name = 'add'; Format = 'add  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'slt'; Format = 'slt  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'sltu'; Format = 'sltu [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'and'; Format = 'and  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'or'; Format = 'or   [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'xor'; Format = 'xor  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'sll'; Format = 'sll  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'srl'; Format = 'srl  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'sra'; Format = 'sra  [D], [S], [T]'; TypeFlags = [InstructionType]::TwoRegisterIn }

    [PSCustomObject]@{ BitPattern = '1000DDDDDSSSSS10'; Name = 'c.mv'; Format = 'c.mv  [D], [S]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '1001DDDDDSSSSS10'; Name = 'c.add'; Format = 'c.add [D], [S]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100011DDD11SSS01'; Name = 'c.and'; Format = 'c.and [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100011DDD10SSS01'; Name = 'c.or'; Format = 'c.or  [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100011DDD01SSS01'; Name = 'c.xor'; Format = 'c.xor [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100011DDD00SSS01'; Name = 'c.sub'; Format = 'c.sub [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'slti'; Format = 'slti  [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'sltiu'; Format = 'sltiu [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'addi'; Format = 'addi  [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'andi'; Format = 'andi  [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'ori'; Format = 'ori   [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'xori'; Format = 'xori  [D], [S], [I12]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'slli'; Format = 'slli  [D], [S], [I5]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'srli'; Format = 'srli  [D], [S], [I5]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'srai'; Format = 'srai  [D], [S], [I5]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'lui'; Format = 'lui   [D], [I20]'; TypeFlags = [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'auipc'; Format = 'auipc [D], [I20]'; TypeFlags = [InstructionType]::Immediate }

    [PSCustomObject]@{ BitPattern = '010IDDDDDIIIII01'; Name = 'c.li'; Format = 'c.li  [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '011IDDDDDIIIII01'; Name = 'c.lui'; Format = 'c.lui [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '000IDDDDDIIIII01'; Name = 'c.addi'; Format = 'c.addi [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '011I00010IIIII01'; Name = 'c.addi16sp'; Format = 'c.addi16sp sp, [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '000IIIIIIIIDDD00'; Name = 'c.addi4spn'; Format = 'c.addi4spn [Dc], sp, [I8]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100I10DDDIIIII01'; Name = 'c.andi'; Format = 'c.andi [Dc], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '000IDDDDDIIIII10'; Name = 'c.slli'; Format = 'c.slli [D], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100I00DDDIIIII01'; Name = 'c.srli'; Format = 'c.srli [Dc], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '100I01DDDIIIII01'; Name = 'c.srai'; Format = 'c.srai [Dc], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '000I00000IIIII01'; Name = 'c.nop'; Format = 'c.nop'; TypeFlags = [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'jal'; Format = 'jal [D], [I20]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'jalr'; Format = 'jalr [D], [S], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate }

    [PSCustomObject]@{ BitPattern = '101IIIIIIIIIII01'; Name = 'c.j'; Format = 'c.j [I11]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '001IIIIIIIIIII01'; Name = 'c.jal'; Format = 'c.jal [I11]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }

    [PSCustomObject]@{ BitPattern = '1000DDDDD0000010'; Name = 'c.jr'; Format = 'c.jr   [D]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '1001DDDDD0000010'; Name = 'c.jalr'; Format = 'c.jalr [D]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'beq'; Format = 'beq  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bne'; Format = 'bne  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'blt'; Format = 'blt  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bltu'; Format = 'bltu [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bge'; Format = 'bge  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bgeu'; Format = 'bgeu [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }

    [PSCustomObject]@{ BitPattern = '110IIISSSIIIII01'; Name = 'c.beqz'; Format = 'c.beqz [Sc], [I8]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '111IIISSSIIIII01'; Name = 'c.bnez'; Format = 'c.bnez [Sc], [I8]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'lw'; Format = 'lw  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lh'; Format = 'lh  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lhu'; Format = 'lhu [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lb'; Format = 'lb  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lbu'; Format = 'lbu [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sw'; Format = 'sw  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sh'; Format = 'sh  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sb'; Format = 'sb  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }

    [PSCustomObject]@{ BitPattern = '010IDDDDDIIIII10'; Name = 'c.lwsp'; Format = 'c.lwsp  [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '010IIISSSIIDDD00'; Name = 'c.lw'; Format = 'c.lw    [Dc], [I6](Sc)'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '110IIIIIISSSSS10'; Name = 'c.swsp'; Format = 'c.swsp  [S], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ BitPattern = '110IIIDDDIISSS00'; Name = 'c.sw'; Format = 'c.sw    [Sc], [I6](Dc)'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
);

function GetInstructions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [InstructionType] $Required = 0,
        [Parameter(Mandatory = $false)]
        [InstructionType] $Blacklist = 0
    )
    $script:INSTRUCTION_SET | Where-Object {(($_.TypeFlags -BAND $Required) -EQ $Required) -AND (($_.TypeFlags -BAND $Blacklist) -EQ 0)}
}

function CheckCompressedReg([string]$RegName) { return ($RegName -in @('s0','fp','s1','a0','a1','a2','a3','a4','a5','x8','x9','x10','x11','x12','x13','x14','x15'));}

function FormatInstruction
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'InstrName')]
        [string] $Instr,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'InstrObj')]
        [PSCustomObject] $InstrObj,
        [Parameter(Mandatory = $false)]
        [string] $Dest,
        [Parameter(Mandatory = $false)]
        [string] $Src1,
        [Parameter(Mandatory = $false)]
        [string] $Src2,
        [Parameter(Mandatory = $false)]
        [int] $Immediate = [int]::MinValue,
        [Parameter(Mandatory = $false)]
        [string] $Name
    )
    if ($Instr)
    {
        $Instruction = ($script:INSTRUCTION_SET | Where-Object {$_.Name -EQ $Instr});
        if ($Instruction.Count -EQ 0) { throw "Instruction '$Instr' could not be found."; }
        if ($Instruction.Count -GT 1) { throw "Instruction '$Instr' has more than one definition."; }
    }
    else { $Instruction = $InstrObj; }

    [string] $Line = "$($Instruction.Format) // #TESTINSTR#$Name";
    if ($Line -match '\[Dc\]')
    {
        if (-NOT $Dest) { $Dest = "x$(Get-Random -Minimum 8 -Maximum 16)"; } # Maximum is exclusive D:<
        if (-NOT (CheckCompressedReg $Dest)) { throw "Instruction '$Instr' cannot be used with register dest $Dest, as it is outside the compressed register set."; }
        $Line = $Line -replace '\[Dc\]',$Dest;
    }
    if ($Line -match '\[Sc\]')
    {
        if (-NOT $Src1) { $Src1 = "x$(Get-Random -Minimum 8 -Maximum 16)"; }
        if (-NOT (CheckCompressedReg $Src1)) { throw "Instruction '$Instr' cannot be used with register src1 $Src1, as it is outside the compressed register set."; }
        $Line = $Line -replace '\[Sc\]',$Src1;
    }
    if ($Line -match '\[Tc\]')
    {
        if (-NOT $Src2) { $Src2 = "x$(Get-Random -Minimum 8 -Maximum 16)"; }
        if (-NOT (CheckCompressedReg $Src2)) { throw "Instruction '$Instr' cannot be used with register src2 $Src2, as it is outside the compressed register set."; }
        $Line = $Line -replace '\[Tc\]',$Src2;
    }
    if ($Line -match '\[D\]')
    {
        if (-NOT $Dest) { $Dest = "x$(Get-Random -Minimum 0 -Maximum 16)"; } # TODO: Maybe replace this with a list of possibilities?
        $Line = $Line -replace '\[D\]',$Dest;
    }
    if ($Line -match '\[S\]')
    {
        if (-NOT $Src1) { $Src1 = "x$(Get-Random -Minimum 0 -Maximum 16)"; }
        $Line = $Line -replace '\[S\]',$Src1;
    }
    if ($Line -match '\[T\]')
    {
        if (-NOT $Src2) { $Src2 = "x$(Get-Random -Minimum 0 -Maximum 16)"; }
        $Line = $Line -replace '\[T\]',$Src2;
    }
    if ($Line -match '\[I(\d+)\]')
    {
        #TODO: Handle unsigned args, there's one or two
        [int]$BitCount = $Matches[1];
        [int]$SignedRange = [Math]::Pow(2, $BitCount - 1);
        if ($Immediate -EQ [int]::MinValue) { $Immediate = Get-Random -Minimum -$SignedRange -Maximum $SignedRange; }
        if (($Immediate -LT -$SignedRange) -OR ($Immediate -GT $SignedRange)) { throw "Instruction '$Instr' has a ${BitCount}b immediate, but the supplied value $Immediate is outside of this range."; }
        $Line = $Line -replace '\[I\d+\]',$Immediate;
    }
    return $Line;
}

function BuildTest([string] $TestName, [switch] $NoFlash)
{
    $script:ACTIONS_ENUM_ONLY = $false;
    $script:TARGET = $TestName;
    $script:CH32V003FUN = (Join-Path $PSScriptRoot '../Firmware/ch32v003fun/ch32v003fun');
    $script:MINICHLINK = (Join-Path $PSScriptRoot '../Firmware/ch32v003fun/minichlink');
    $script:ADDITIONAL_C_FILES += @($(Join-Path $PSScriptRoot "/Generated/$TestName.S"));
    $script:OVERRIDE_C = (Join-Path $PSScriptRoot '../Firmware/Firmware.c')
    
    if (Test-Path "$PSScriptRoot/../Firmware/supplemental/build_scripts/ch32v003fun_base.ps1") { . "$PSScriptRoot/../Firmware/supplemental/build_scripts/ch32v003fun_base.ps1"; }
    else { . "$PSScriptRoot/../Firmware/ch32v003fun/build_scripts/ch32v003fun_base.ps1"; }
    if ($NoFlash) { ExecuteActions 'build'; }
    else { ExecuteActions 'cv_flash'; }
}

function ExportMarkerLocations
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $LSTFile,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $OutputFile,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $MarkerRegex,
        [Parameter(Mandatory = $false)]
        [uint] $CheckOpcode
    )

    try
    {
        if (!(Test-Path $LSTFile)) { throw "LST file cannot be searched for markers '$MarkerRegex' as the file doesn't exist."; }
        # Write-Host "Reading file for marker locations: '$LSTFile'";
        [StreamReader] $InputFileReader = [StreamReader]::new($LSTFile);
        $OutputData = @();
        $ReturnData = @();
        [string] $Line = $InputFileReader.ReadLine();
        while (!($InputFileReader.EndOfStream))
        {
            $Line = $InputFileReader.ReadLine();

            if ($Line -match $MarkerRegex)
            {
                [int] $TestID = $Matches[1];
                [string] $NextLine = $InputFileReader.ReadLine();
                if ($NextLine -match '^\s*([\da-fA-F]+):\s*([\da-fA-F]+)\s+')
                {
                    [uint] $Location = 0;
                    if (!([uint]::TryParse($Matches[1], [System.Globalization.NumberStyles]::HexNumber, $null, [ref]$Location)))
                    {
                        Write-Error "Failed to parse line for location after marker for '$MarkerRegex' at test ID $TestID. Line was '$NextLine'";
                        continue;
                    }
                    if ($PSBoundParameters.ContainsKey('CheckOpcode'))
                    {
                        [uint] $InstrCode = 0;
                        if (!([uint]::TryParse($Matches[2], [System.Globalization.NumberStyles]::HexNumber, $null, [ref]$InstrCode)))
                        {
                            Write-Error "Failed to parse line for instruction code after marker for '$MarkerRegex' at test ID $TestID. Line was '$NextLine'";
                            continue;
                        }
                        if ($InstrCode -NE $CheckOpcode)
                        {
                            Write-Error $("Found incorrect instruction code 0x'{0:X8}' (expected 0x{1:X8}) after marker for '{2}' at test ID {3}. Line was '{4}'" -F $InstrCode, $Opcode, $MarkerRegex, $TestID, $NextLine);
                            continue;
                        }
                    }
                    $OutputData += $('{0},{1:X8}' -F $TestID, $Location);
                    $ReturnData += $Location;
                }
                
            }
        }
        Set-Content -Path $OutputFile -Value $OutputData;
        return $ReturnData;
    }
    finally
    {
        if ($InputFileReader) { $InputFileReader.Close(); }
    }
}

function ReplaceInstruction
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $BinFile,
        [Parameter(Mandatory = $true)]
        [string] $OutputFile,
        [Parameter(Mandatory = $true)]
        [uint] $Location,
        [Parameter(Mandatory = $true)]
        [uint] $New,
        [Parameter(Mandatory = $false)]
        [uint] $Expect,
        [switch] $Compressed
    )

    [byte[]] $BinBytes = [File]::ReadAllBytes($BinFile);
    [int] $InstrSize = 4;
    if ($Compressed) { $InstrSize = 2; }
    [bool] $DoCheck = $PSBoundParameters.ContainsKey('Expect');

    for ($i = 0; $i -LT $InstrSize; $i++)
    {
        [int] $BinLocation = $Location + $i;

        [byte] $Expected = ($Expect -SHR ($i * 8)) -BAND 0xFF;
        # Write-Host $("Expecting {0:X2} at location 0x{1:X8}" -F $Expected, $BinLocation);

        if ($DoCheck -AND ($Expected -NE $BinBytes[$BinLocation])) { throw $("Expected byte 0x{0:X2} at location 0x{1:X8}, but found 0x{2:X2} instead" -F $Expected, $BinLocation, $BinBytes[$BinLocation]); }

        [byte] $NewByte = ($New -SHR ($i * 8)) -BAND 0xFF;
        $BinBytes[$BinLocation] = $NewByte;
    }

    [File]::WriteAllBytes($OutputFile, $BinBytes);
}

$JANKY_WORKAROUND = @"
using System;
using System.Diagnostics;
public class JankyWorkaround
{
    public Process Process;
    public bool GotFailure = false;
    public bool GotReady = false;
    public void Start(string args)
    {
        ProcessStartInfo Info = new ProcessStartInfo()
        {
            FileName = "C:\\Program Files\\sigrok\\sigrok-cli\\sigrok-cli.exe",
            Arguments = args,
            UseShellExecute = false,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };
        this.Process = Process.Start(Info);
        this.Process.EnableRaisingEvents = true;
        this.Process.OutputDataReceived += HandleOutput;
        this.Process.ErrorDataReceived += HandleOutput;
        this.Process.BeginOutputReadLine();
        this.Process.BeginErrorReadLine();
    }
    private void HandleOutput(object sender, DataReceivedEventArgs evt)
    {
        if (evt.Data == null) { return; }
        if (evt.Data == "Failed to open device.") { this.GotFailure = true; }
        if (evt.Data == "sr: session: Starting.") { this.GotReady = true; }
        //Console.WriteLine("SIGROK>" + evt.Data);
    }
}
"@

function StartListenerSigrok([string] $csvFile)
{
    if (!('JankyWorkaround' -as [Type]))
    {
        Write-Host 'Adding the JankyWorkaround class...';
        Add-Type -TypeDefinition $JANKY_WORKAROUND;
    }
    else { Write-Host 'WARNING: The JankyWorkaround class has already been loaded previously, no further changes to it will be reflected in this session.' }
    [JankyWorkaround] $Jank = [JankyWorkaround]::new();

    $ArgList = @(
        '--driver', 'dreamsourcelab-dslogic',
        '--config', '"voltage_threshold=1.2-1.2:samplerate=100M"',
        '--output-file', "`"$csvFile`"",
        '--output-format', '"csv:time=true:dedup=true:header=false"',
        '--channels', '0,1,2',
        '--triggers', '1=r',
        '--samples', '50000',
        '--loglevel', '3' # Why doesn't this one have a hyphen in the name???
    );

    $Jank.Start($ArgList);

    $Timeout = $(Get-Date) + [TimeSpan]::FromSeconds(10);
    while (!$Jank.GotFailure -AND !$Jank.GotReady -AND ($Timeout -GT $(Get-Date)))
    {
        #Write-Host "Got fail? $($Jank.GotFailure), Got ready? $($Jank.GotReady)";
        Start-Sleep -Milliseconds 500;
    }

    if ($Jank.GotFailure) { throw 'Sigrok failed to connect to the logic analyzer. Try replugging it or throwing Sigrok out the window in anger?'; }
    elseif (!$Jank.GotReady) { throw 'Timed out waiting for Sigrok. Try replugging the logic analyzer?'; }

    return $Jank.Process;
}

function StartAHKScript
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $scriptFile,
        [Parameter(Mandatory = $false, Position = 1)]
        $AHKargs
    )
    $AHK_LOCATION = 'C:\Program Files\AutoHotkey\AutoHotkey.exe';
    $AHKProc = $(Start-Process -Wait $AHK_LOCATION -ArgumentList $(Flatten @($scriptFile, $AHKargs)) -PassThru);
    if ($AHKProc.ExitCode -NE 0) { throw "AHK returned exit code $($AHKProc.ExitCode)."; }
}

function ParseCapture([string] $csvFile, [string] $outputPath, [switch] $NoOutFile)
{
    $OutputData = @();
    # Write-Host "Saving intermediate cycle-counted capture to $outputPath";

    try
    {
        [StreamReader] $InputFile = [StreamReader]::new($csvFile);
        if(!$NoOutFile) { [StreamWriter] $OutputFile = [StreamWriter]::new($outputPath); }

        [int] $LastClock = 0;
        [int] $LastClockedData = 0;
        [int] $LastRawData = 0;
        [int] $TimeSinceLastDataTrans = 1;

        [string] $Line = $InputFile.ReadLine();
        while ($Line -notmatch '^\d') { $Line = $InputFile.ReadLine(); } # Skip all header lines
        [string] $PrevLine = '';
        [float] $PrevNanoseconds;

        while (!([string]::IsNullOrEmpty($Line)))
        {
            [int] $CommaIndex = $Line.IndexOf([char]',');
            if ($CommaIndex -LE 0) { $Line = $InputFile.ReadLine(); continue; }
            [int] $Clock = $Line[$CommaIndex + 1] - [char]'0';
            [int] $Data = $Line[$CommaIndex + 3] - [char]'0';
            [string] $NanosecondsStr = $Line.Substring(0, $CommaIndex);
            [float] $Nanoseconds = 0;
            if ([float]::TryParse($NanosecondsStr, [ref]$Nanoseconds))
            {
                [float] $CyclesSinceLastClock = ($Nanoseconds - $PrevNanoseconds) * 48000000;
                if ($CyclesSinceLastClock -GT 3)
                {
                    if(!$NoOutFile) { $OutputFile.WriteLine("$NanosecondsStr,$CyclesSinceLastClock,2"); }
                    $OutputData += [PSCustomObject]@{ Nanoseconds = $NanosecondsStr; CycleCount = $CyclesSinceLastClock; Bit = -1 };
                    Write-Host "Found $CyclesSinceLastClock missing clock cycles!";
                }
            }
            else { Write-Error "Could not parse nanoseconds number from '$NanosecondsStr'. Clock fail detection will not work."; }

            if ($Clock -GT $LastClock) # Clock rising edge
            {
                if (($LastRawData -BXOR $LastClockedData) -NE 0) # Data transition (sample right before the clock rising edge)
                {
                    if(!$NoOutFile) { $OutputFile.WriteLine("$NanosecondsStr,$TimeSinceLastDataTrans,$LastClockedData"); }
                    $OutputData += [PSCustomObject]@{ Nanoseconds = $NanosecondsStr; CycleCount = $TimeSinceLastDataTrans; Bit = $LastClockedData };
                    $TimeSinceLastDataTrans = 1;
                }
                else { $TimeSinceLastDataTrans++; }
                $LastClockedData = $LastRawData;
            }
            $LastClock = $Clock;
            $LastRawData = $Data;
            $PrevLine = $Line;
            $PrevNanoseconds = $Nanoseconds;
            $Line = $InputFile.ReadLine();
        }

        # Output one last entry for the last state
        [int] $CommaIndex = $PrevLine.IndexOf([char]',');
        if ($CommaIndex -LE 0) { Write-Error 'Couldn''t parse last line'; }
        [string] $NanosecondsStr = $PrevLine.Substring(0, $CommaIndex);
        if(!$NoOutFile) { $OutputFile.WriteLine("$NanosecondsStr,$TimeSinceLastDataTrans,$LastClockedData"); }
        $OutputData += [PSCustomObject]@{ Nanoseconds = $NanosecondsStr; CycleCount = $TimeSinceLastDataTrans; Bit = $LastClockedData };
        
        return $OutputData;
    }
    finally
    {
        if($InputFile) { $InputFile.Close(); }
        if(!$NoOutFile -AND $OutputFile) { $OutputFile.Close(); }
    }
}


# TODO: Figure out why this is broken right now!
function ParseProcessedFile([string] $fileName)
{
    try
    {
        [StreamReader] $Reader = [StreamReader]::new($fileName);
        $OutputData = @();
        [string] $Line = $Reader.ReadLine();
        while(!$Reader.EndOfStream)
        {
            [int] $CommaIndex = $Line.IndexOf([char]',');
            [int] $CommaIndex2 = $Line.IndexOf([char]',', $CommaIndex + 1);
            [string] $Nanoseconds = $Line.Substring(0, $CommaIndex);
            [int] $CycleCount = $Line.Substring($CommaIndex + 1, ($CommaIndex2 - $CommaIndex - 1));
            [int] $Bit = $Line.Substring($CommaIndex2 + 1);
            if ($Bit -EQ 2) { $Bit = -1; }
            $OutputData += [PSCustomObject]@{ Nanoseconds = $Nanoseconds; CycleCount = $CycleCount; Bit = $Bit };

            $Line = $Reader.ReadLine();
        }
        return $OutputData;
    }
    finally
    {
        if ($Reader) { $Reader.Close(); }
    }
}

function ReadSingleTest($DataArr, [ref] $Index, [switch] $SeekOnly)
{
    # Start Fence
    $Data = $DataArr[$Index.Value++];
    while (($Data.CycleCount -NE 10) -OR ($Data.Bit -NE 1)) { $Data = $DataArr[$Index.Value++]; }
    $Data = $DataArr[$Index.Value++];

    # Test ID
    if ($Data.Bit -NE 0) { throw 'Did not see a 0 bit to start the test ID'; }
    [UInt16] $TestID = 0;
    $IDCycles = 0;
    while ($IDCycles -LT 20)
    {
        if (($Data.CycleCount % 2) -NE 0) { throw 'Saw a non-even number of cycles in an entry while parsing the test ID.'; }
        $TestID = $TestID -SHL ($Data.CycleCount / 2);
        if ($Data.Bit -EQ 1) { $TestID = $TestID -BOR [UInt16]([Math]::Pow(2, ($Data.CycleCount / 2)) - 1); }
        $IDCycles += $Data.CycleCount;
        $Data = $DataArr[$Index.Value++];
    }
    # TODO: Probably need to shift the ID right one to remove the extra cycle at the end
    # TODO: Actually use ID, don't just assume 1 after another

    # Mid Fence
    if (($Data.CycleCount -NE 10) -OR ($Data.Bit -NE 1)) { throw 'Could not find mid fence'; }
    if ($SeekOnly) { return; } # This just puts Index in the right location to read the test results, but lets the user do that.
    $Data = $DataArr[$Index.Value++];

    # Test
    $TestData = @();
    while (($Data.CycleCount -NE 20) -OR ($Data.Bit -NE 1))
    {
        $TestData += $Data;
        $Data = $DataArr[$Index.Value++];
    }

    return $TestData;
}
