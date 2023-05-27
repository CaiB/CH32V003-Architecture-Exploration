# CH32V003-Architecture-Exploration

My attempts to poke at the CH32V003 chip to learn about its instruction timings and architecture.

The tools used in this process were built quickly, and are not of high quality. I hope you don't need to use them.

Still extremely unfinished.


Example capture command:
```powershell
'C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe' --driver 'dreamsourcelab-dslogic' --config 'voltage_threshold=1.2-1.2:samplerate=400M' --output-file test.csv --output-format 'csv:time=true:dedup=true:header=false' --channels 0 --time 100
```

## Sigrok
A very special award goes to Sigrok for overall jankyness and bad documentation.  
I still have no idea whether there actually is an API to set up triggers, do captures, and get data out. I ended up using sigrok-cli instead because it's all I could find.  

And the jank:  
According to [this page](https://sigrok.org/wiki/Sigrok-cli), `--output-format`:
> `$ sigrok-cli [...] -o example.csv -O csv:dedup:header=false`  
> Notice that boolean options are true when no value gets specified.

which appears to be a complete lie, I had to add `=true` to get these working.  


Next:
> `--time <ms>`  
> Sample for \<ms\> milliseconds, then quit.

Even though this should just control how long the capture is, it didn't work until I added `time=true` to the csv [output format params](https://sigrok.org/wiki/File_format:Csv). Otherwise it just captured indefinitely. Then once I enabled triggering, I could never get time to work again, it always just captures indefinitely.


I seem to always get data corruption near the end of the sampling period, regardless of how long I make it. Channels just get swapped randomly. What excellent high quality software.

