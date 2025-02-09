[CmdletBinding()]
param()
DynamicParam
{
    # Tell it what it needs to know
    $script:ACTIONS_ENUM_ONLY = $true;
    $script:TARGET = 'Firmware';

    # Source it
    if (Test-Path './supplemental/build_scripts/ch32fun_base.ps1') { . ./supplemental/build_scripts/ch32fun_base.ps1 }
    else { . ./ch32v003fun/build_scripts/ch32fun_base.ps1 }

    # Add our actions
    $script:AVAIL_ACTIONS += @{
        'all' = 'DoCVFlash';
        'flash' = 'DoCVFlash';
        'clean' = 'DoCVClean';
    };

    return $(CreateActionParam);
}
Process
{
    $Actions = $PSBoundParameters['Actions'];
    $script:ACTIONS_ENUM_ONLY = $false;

    $script:TARGET = 'Firmware';
    $script:ch32fun = './ch32v003fun/ch32fun';
    $script:MINICHLINK = './ch32v003fun/minichlink';
    $script:ADDITIONAL_C_FILES += @('RunTests.S');
    
    if (Test-Path './supplemental/build_scripts/ch32fun_base.ps1') { . ./supplemental/build_scripts/ch32fun_base.ps1 }
    else { . ./ch32v003fun/build_scripts/ch32fun_base.ps1 }
    ExecuteActions $Actions;
}
