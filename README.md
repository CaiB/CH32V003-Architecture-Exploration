# CH32V003-Architecture-Exploration

My attempts to poke at the CH32V003 chip to learn about its instruction timings and architecture.

The tools used in this process were built quickly, and are not of high quality. I hope you don't need to use them.

Still extremely unfinished.

## Running
You'll need:
- Windows
- A logic analyzer capable of _over_ 100MHz. 200MHz works, 400MHz is ideal. Only 2-3 channels needed
    - If a DSLogic Plus (or other >100MHz), the [DSView](https://github.com/DreamSourceLab/DSView/releases) software and [AutoHotKey](https://www.autohotkey.com/) are also recommended
    - Otherwise, if it works with [Sigrok](https://sigrok.org/wiki/Sigrok-cli) and Sigrok works at all, that is semi-supported
    - Otherwise, you can manually export the data to CSV from any other software. 
        - Make sure to "compress"/"deduplicate" the data.
        - Expected line format: `nanoseconds,CH0,CH1[,CH2]`
- A CH32V003 and a programmer compatible with [minichlink](https://github.com/cnlohr/ch32v003fun/tree/master/minichlink)
- Channel 0 connected to PC4
- Channel 1 connected to PD2
- Channel 2 connected to PD4 (optional, currently unused)
- Patience, this thing is a mess right now

## Tests
### Alignment
`.\Alignment.ps1 -CaptureMethod DSViewAHK|SigrokCLI|Manual|None [-Clean] [-NoProgram] [-RandomOrder]`  
Tests how instructions react to alignment on 16b vs 32b boundaries, as well as how much runtime increases with more repeated identical instructions

## Notes
Example Sigrok capture command:
```powershell
'C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe' --driver 'dreamsourcelab-dslogic' --config 'voltage_threshold=1.2-1.2:samplerate=400M' --output-file test.csv --output-format 'csv:time=true:dedup=true:header=false' --channels 0 --time 100
```

## Sigrok
A very special award goes to Sigrok for being practically useless. Even though the wiki says my DSLogic Plus is supported, and there's firmware there, and it lists 400MHz as an option under `--view`, any sample rate above 100MHz corrupts data, fails to trigger, triggers on nothing, doesn't stop capturing, and otherwise just doesn't work at all. THe official DSView software works fine.

**Random other jank:**  
According to [this page](https://sigrok.org/wiki/Sigrok-cli), `--output-format` (`-O`):  
> `$ sigrok-cli [...] -o example.csv -O csv:dedup:header=false`  
> Notice that boolean options are true when no value gets specified.

which appears to be a complete lie, I had to add `=true` to get these working.  

Also,
> `--time <ms>`  
> Sample for \<ms\> milliseconds, then quit.

Even though this should just control how long the capture is, it didn't work until I added `time=true` to the csv [output format params](https://sigrok.org/wiki/File_format:Csv). Otherwise it just captured indefinitely.

