using namespace System.Collections.Generic;

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
        'nop; nop; nop; nop; // x4'
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
        'nop; nop; nop; nop; nop; nop; nop; nop; // x8',
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

    [PSCustomObject]@{ Name = 'c.mv'; Format = 'c.mv  [D], [S]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.add'; Format = 'c.add [D], [S]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.and'; Format = 'c.and [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.or'; Format = 'c.or  [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.xor'; Format = 'c.xor [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.sub'; Format = 'c.sub [Dc], [Sc]'; TypeFlags = [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.nop'; Format = 'c.nop'; TypeFlags = [InstructionType]::Compressed }

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

    [PSCustomObject]@{ Name = 'c.li'; Format = 'c.li  [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.lui'; Format = 'c.lui [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.addi'; Format = 'c.addi [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.addi16sp'; Format = 'c.addi16sp sp, [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.addi4spn'; Format = 'c.addi4spn [Dc], sp, [I8]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.andi'; Format = 'c.andi [Dc], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.slli'; Format = 'c.slli [D], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.srli'; Format = 'c.srli [Dc], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.srai'; Format = 'c.srai [Dc], [I5]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'jal'; Format = 'jal [D], [I20]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate }
    [PSCustomObject]@{ Name = 'jalr'; Format = 'jalr [D], [S], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate }

    [PSCustomObject]@{ Name = 'c.j'; Format = 'c.j [I11]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.jal'; Format = 'c.jal [I11]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'c.jr'; Format = 'c.jr   [D]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.jalr'; Format = 'c.jalr [D]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'beq'; Format = 'beq  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bne'; Format = 'bne  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'blt'; Format = 'blt  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bltu'; Format = 'bltu [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bge'; Format = 'bge  [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }
    [PSCustomObject]@{ Name = 'bgeu'; Format = 'bgeu [S], [T], [I12]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::TwoRegisterIn }

    [PSCustomObject]@{ Name = 'c.beqz'; Format = 'c.beqz [Sc], [I8]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.bnez'; Format = 'c.bnez [Sc], [I8]'; TypeFlags = [InstructionType]::Branch + [InstructionType]::Immediate + [InstructionType]::Compressed }

    [PSCustomObject]@{ Name = 'lw'; Format = 'lw  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lh'; Format = 'lh  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lhu'; Format = 'lhu [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lb'; Format = 'lb  [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'lbu'; Format = 'lbu [D], [I12]([S])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sw'; Format = 'sw  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sh'; Format = 'sh  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }
    [PSCustomObject]@{ Name = 'sb'; Format = 'sb  [S], [I12]([D])'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory }

    [PSCustomObject]@{ Name = 'c.lwsp'; Format = 'c.lwsp  [D], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.lw'; Format = 'c.lw    [Dc], [I6](Sc)'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.swsp'; Format = 'c.swsp  [S], [I6]'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
    [PSCustomObject]@{ Name = 'c.sw'; Format = 'c.sw    [Sc], [I6](Dc)'; TypeFlags = [InstructionType]::Immediate + [InstructionType]::Memory + [InstructionType]::Compressed }
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
        [int] $Immediate = [int]::MinValue
    )
    if ($Instr)
    {
        $Instruction = ($script:INSTRUCTION_SET | Where-Object {$_.Name -EQ $Instr});
        if ($Instruction.Count -EQ 0) { throw "Instruction '$Instr' could not be found."; }
        if ($Instruction.Count -GT 1) { throw "Instruction '$Instr' has more than one definition."; }
    }
    else { $Instruction = $InstrObj; }

    [string] $Line = $Instruction.Format;
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

function BuildTest([string] $TestName)
{
    $script:ACTIONS_ENUM_ONLY = $false;
    $script:TARGET = $TestName;
    $script:CH32V003FUN = (Join-Path $PSScriptRoot '../Firmware/ch32v003fun/ch32v003fun');
    $script:MINICHLINK = (Join-Path $PSScriptRoot '../Firmware/ch32v003fun/minichlink');
    $script:ADDITIONAL_C_FILES += @("Generated/$TestName.S");
    $script:OVERRIDE_C = (Join-Path $PSScriptRoot '../Firmware/Firmware.c')
    
    if (Test-Path '../Firmware/supplemental/build_scripts/ch32v003fun_base.ps1') { . ../Firmware/supplemental/build_scripts/ch32v003fun_base.ps1 }
    else { . ../Firmware/ch32v003fun/build_scripts/ch32v003fun_base.ps1 }
    ExecuteActions 'cv_flash';
}

function StartListener([string] $csvFile)
{
    $ArgList = @(
        '--driver', 'dreamsourcelab-dslogic',
        '--config', 'voltage_threshold=1.2-1.2:samplerate=200M',
        '--output-file', "`"$csvFile`"",
        '--output-format', 'csv:time=true:dedup=true:header=false',
        '--channels', '0,1,2',
        '--triggers', '1=r',
        '--samples', '50000'
    );
    return Start-Process -NoNewWindow 'C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe' -ArgumentList $ArgList -PassThru;
}
