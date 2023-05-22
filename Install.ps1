# Link to download sigrok-cli. Current as of 2023-05-22
# See this page: https://sigrok.org/wiki/Downloads
[string] $SigrockURL = 'https://sigrok.org/download/binary/sigrok-cli/sigrok-cli-0.7.2-x86_64-installer.exe';

# These are the firmware files for the DSLogic Plus. You'll need to change the paths if you're using a different device.
# See this page: https://www.sigrok.org/wiki/DreamSourceLab_DSLogic
# File links are current as of 2023-05-22
$FirmwareFiles = @(
    @{ Filename = 'dreamsourcelab-dslogic-plus-fpga.fw'; URL = 'https://github.com/DreamSourceLab/DSView/raw/886b847c21c606df3138ce7ad8f8e8c363ee758b/DSView/res/DSLogicPlus.bin' }
    @{ Filename = 'dreamsourcelab-dslogic-plus-fx2.fw'; URL = 'https://github.com/DreamSourceLab/DSView/raw/886b847c21c606df3138ce7ad8f8e8c363ee758b/DSView/res/DSLogicPlus.fw' }
);

[string] $SigrockName = 'sigrock-cli-install.exe';
Write-Host 'Downloading sigrok-cli...';
Invoke-WebRequest $SigrockURL -OutFile $SigrockName -UseBasicParsing;

Write-Host 'Installing sigrok-cli...';
Start-Process $SigrockName -ArgumentList '/S' -Wait;

Write-Host 'Downloading Firmware Files...';
[string] $FirmwarePath = Join-Path $env:LOCALAPPDATA '/sigrok-firmware/';
if (!(Test-Path $FirmwarePath)) { New-Item -ItemType 'Directory' -Path $FirmwarePath | Out-Null; }

foreach ($FileEntry in $FirmwareFiles)
{
    Invoke-WebRequest $FileEntry.URL -OutFile (Join-Path $FirmwarePath $FileEntry.Filename) -UseBasicParsing
}

