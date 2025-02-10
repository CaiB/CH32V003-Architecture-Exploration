## 2025-02-10 Alignment
**Goal:** Get a basic guideline of how long compressed and uncompressed instructions take when executed repeatedly, and determine if 4-byte alignment makes any difference.

**Method:** Every instruction type that is not a memory access or branch was executed 5 and 9 times (x5, x9 in name) in a row. The instructions were started on 4-byte alignment ("aligned"), then on 4-byte alignment + 2 bytes offset ("misaligned").  
> Uncompressed instructions are 4 bytes long, compressed are 2 bytes long, so alignment theoretically would only affect compressed instructions.

**Results:**
- `.\Alignment.ps1 -CaptureMethod DSViewAHK` -> `Analysis/Alignment/Alignment-00-Default.csv`
- `.\Alignment.ps1 -CaptureMethod DSViewAHK -RandomOrder` -> `Analysis/Alignment/Alignment-01-Shuffled.csv`, `Alignment-02-CompressedFirst.csv`
- `.\Alignment.ps1 -CaptureMethod DSViewAHK -MisalignFirst` -> `Analysis/Alignment/Alignment-03-MisalignFirst.csv`

### Analysis
- All compressed instructions took 5 cycles to run 5 times, and 9 cycles to run 9 times.
  - Compressed instructions (non-memory, non-branch) appear to execute at 1 CPI.
- All but one uncompressed instructions took 8 cycles to run 5 times, and 16 cycles to run 9 times.
  - Uncompressed instructions may execute at 1 CPI for the first two, then slow down to 2 CPI for all remaining ones?
- The exception was 7 cycles for 5 aligned. The exception for the uncompressed instruction is always the very first test that is run, regardless of which uncompressed instruction is there.
  - Something to do with its location in the program? Entry point is 0xA0, first test instruction is at 0xF8 (aligned) or 0xFA (misaligned).
- However, when the first uncompressed instruction was misaligned, rather than aligned, execution time when from 7 (1 less than expected 8) to 9 (1 _more_ than expected 8).
  - Need to determine why this first test is exhibiting behaviour not seen in any other test, as alignment has significant effect when this condition is present.
- When the very first test that was run was a compressed instruction, it did not vary the time taken.
