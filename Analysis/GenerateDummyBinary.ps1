[string] $OutputFile = (Join-Path $PSScriptRoot 'GenerateDummyBinary.bin');
[string] $OutputFileLST = (Join-Path $PSScriptRoot 'GenerateDummyBinary.lst');
[byte[]] $Binary = [byte[]]::new(65536 * 2);
[int] $BinaryIndex = 0;
for ($Instr = 0; $Instr -LT 0xFFFF; $Instr++)
{
    if (($Instr -BAND 3) -EQ 3) { continue; }
    $Binary[$BinaryIndex++] = ($Instr -BAND 0xFF);
    $Binary[$BinaryIndex++] = (($Instr -SHR 8) -BAND 0xFF);
}

[System.IO.File]::WriteAllBytes($OutputFile, $Binary);

Start-Process -NoNewWindow -Wait 'riscv64-unknown-elf-objdump' -ArgumentList @('-b', 'binary', '-m', 'riscv', '-D', $OutputFile) -RedirectStandardOutput $OutputFileLST;
