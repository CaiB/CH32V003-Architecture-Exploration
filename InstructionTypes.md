# Registers
| Reg Nmbr | ABI Name | Compressed | Preserved by callee | Description |
|----------|----------|------------|---------------------|-------------|
|   `x0`   |  `zero`  |     N/A    |         N/A         | Hardwired zero
|   `x1`   |   `ra`   |     N/A    |         :x:         | Return address
|   `x2`   |   `sp`   |     N/A    | :heavy_check_mark:  | Stack pointer
|   `x3`   |   `gp`   |     N/A    |         N/A         | Global pointer
|   `x4`   |   `tp`   |     N/A    |         N/A         | Thread pointer
|   `x5`   |   `t0`   |     N/A    |         :x:         | Temp reg 0
|   `x6`   |   `t1`   |     N/A    |         :x:         | Temp reg 1
|   `x7`   |   `t2`   |     N/A    |         :x:         | Temp reg 2
|   `x8`   | `s0`/`fp`|    `000`   | :heavy_check_mark:  | Saved reg 0 / Frame pointer
|   `x9`   |   `s1`   |    `001`   | :heavy_check_mark:  | Saved reg 1
|   `x10`  |   `a0`   |    `010`   |         :x:         | Return val 0
|   `x11`  |   `a1`   |    `011`   |         :x:         | Function arg 1 / Return val 1
|   `x12`  |   `a2`   |    `100`   |         :x:         | Function arg 2
|   `x13`  |   `a3`   |    `101`   |         :x:         | Function arg 3
|   `x14`  |   `a4`   |    `110`   |         :x:         | Function arg 4
|   `x15`  |   `a5`   |    `111`   |         :x:         | Function arg 5

Register names used below with apostrophe (e.g. `SRC'`) are one of the 8 in the compressed set.

# Instructions
## Arithmetic
```
 Instruction                |  Operation
add  [DEST], [SRC1], [SRC2] | DEST = SRC1 + SRC2
slt  [DEST], [SRC1], [SRC2] | DEST = (  signed(SRC1) <   signed(SRC2)) ? 1 : 0
sltu [DEST], [SRC1], [SRC2] | DEST = (unsigned(SRC1) < unsigned(SRC2)) ? 1 : 0
and  [DEST], [SRC1], [SRC2] | DEST = SRC1 & SRC2
or   [DEST], [SRC1], [SRC2] | DEST = SRC1 | SRC2
xor  [DEST], [SRC1], [SRC2] | DEST = SRC1 ^ SRC2
sll  [DEST], [SRC1], [SRC2] | DEST = SRC1 <<  SRC2[4:0]
srl  [DEST], [SRC1], [SRC2] | DEST = SRC1 >>> SRC2[4:0]
sra  [DEST], [SRC1], [SRC2] | DEST = SRC1 >>  SRC2[4:0]
```

### Arithmetic: `compressed`
```
 Binary             |  Instruction          |  Operation   |  Notes
1000 DDDD DSSS SS10 | c.mv  [DEST],  [SRC]  | DEST   = SRC | SRC cannot be x0, DEST cannot be x0
1001 DDDD DSSS SS10 | c.add [DEST],  [SRC]  | DEST  += SRC | SRC cannot be x0, DEST cannot be x0
1000 11DD D11S SS01 | c.and [DEST'], [SRC'] | DEST' &= SRC'
1000 11DD D10S SS01 | c.or  [DEST'], [SRC'] | DEST' |= SRC'
1000 11DD D01S SS01 | c.xor [DEST'], [SRC'] | DEST' ^= SRC'
1000 11DD D00S SS01 | c.sub [DEST'], [SRC'] | DEST' -= SRC'
```

### Arithmetic: `immediate`
Immediate bits are often not in order
```
 Instruction               |  Operation
slti  [DEST], [SRC], [IMM] | DEST = (  signed(SRC) <          SE(12b immediate))  ? 1 : 0
sltiu [DEST], [SRC], [IMM] | DEST = (unsigned(SRC) < unsigned(SE(12b immediate))) ? 1 : 0
addi  [DEST], [SRC], [IMM] | DEST = SRC + SE(12b immediate)
andi  [DEST], [SRC], [IMM] | DEST = SRC & SE(12b immediate)
ori   [DEST], [SRC], [IMM] | DEST = SRC | SE(12b immediate)
xori  [DEST], [SRC], [IMM] | DEST = SRC ^ SE(12b immediate)
slli  [DEST], [SRC], [IMM] | DEST = SRC <<  (5b immediate)
srli  [DEST], [SRC], [IMM] | DEST = SRC >>> (5b immediate)
srai  [DEST], [SRC], [IMM] | DEST = SRC >>  (5b immediate)
lui   [DEST], [IMM]        | DEST = {(20b immediate), '0}
auipc [DEST], [IMM]        | DEST = {(20b immediate), '0} + pc
```

### Arithmetic: `immediate`, `compressed`
Immediate bits are often not in order
```
 Binary             |  Instruction                  |  Operation                       |  Notes
010I DDDD DIII II01 | c.li [DEST], [IMM]            | DEST =  SE(6b immediate)         | DEST cannot be x0
011I DDDD DIII II01 | c.lui [DEST], [IMM]           | DEST = {SE(6b immediate), 12'b0} | IMM cannot be 0, DEST cannot be x0 or x2 (sp)
000I DDDD DIII II01 | c.addi [DEST], [IMM]          | DEST +=  SE(6b immediate)        | IMM cannot be 0
011I 0001 0III II01 | c.addi16sp sp, [IMM]          | sp   += (SE(6b immediate) * 16B) | IMM cannot be 0 (has effective range -512..496)
000I IIII IIID DD00 | c.addi4spn [DEST'], sp, [IMM] | DEST' = sp + (unsigned(8b immediate) * 4B) | IMM cannot be 0
100I 10DD DIII II01 | c.andi [DEST'], [IMM]         | DEST' &= SE(6b immediate)
000I DDDD DIII II10 | c.slli [DEST], [IMM]          | DEST  <<=  (5b immediate)        | DEST cannot be x0
100I 00DD DIII II01 | c.srli [DEST'], [IMM]         | DEST' >>>= (5b immediate)
100I 01DD DIII II01 | c.srai [DEST'], [IMM]         | DEST' >>=  (5b immediate)
000I 0000 0III II01 | c.nop                         | ;                                | Immediate cannot be zero, not required in ASM
```

## Unconditional control flow
### Unconditional control flow: `immediate`, `branch`
Immediate bits are often not in order
```
 Instruction              |  Operation
jal  [DEST], [IMM]        | DEST = pc + 4B; pc += (SE(20b immediate) * 2B);
jalr [DEST], [SRC], [IMM] | DEST = pc + 4B; pc  = (SE(12b immediate) + SRC) & 0xFFFFFFFE;
```

### Unconditional control flow: `immediate`, `branch`, `compressed`
Immediate bits are often not in order
```
 Binary             |  Instruction |  Operation
101I IIII IIII II01 | c.j [IMM]    |               pc += (SE(11b immediate) * 2B)
001I IIII IIII II01 | c.jal [IMM]  | x1 = pc + 2B; pc += (SE(11b immediate) * 2B)
```

### Unconditional control flow: `branch`, `compressed`
```
 Binary             |  Instruction  |  Operation              |  Notes
1000 DDDD D000 0010 | c.jr   [DEST] |               pc = DEST | DEST cannot be x0
1001 DDDD D000 0010 | c.jalr [DEST] | x1 = pc + 2B; pc = DEST | DEST cannot be x0
```

## Conditional control flow
### Conditional control flow: `immediate`, `branch`
Immediate bits are often not in order
```
 Instruction               |  Operation
beq  [SRC1], [SRC2], [IMM] | pc += (SRC1 == SRC2) ? (SE(12b immediate) * 2B) : 4B
bne  [SRC1], [SRC2], [IMM] | pc += (SRC1 != SRC2) ? (SE(12b immediate) * 2B) : 4B
blt  [SRC1], [SRC2], [IMM] | pc += (  signed(SRC1) <    signed(SRC2)) ? (SE(12b immediate) * 2B) : 4B
bltu [SRC1], [SRC2], [IMM] | pc += (unsigned(SRC1) <  unsigned(SRC2)) ? (SE(12b immediate) * 2B) : 4B
bge  [SRC1], [SRC2], [IMM] | pc += (  signed(SRC1) >=   signed(SRC2)) ? (SE(12b immediate) * 2B) : 4B
bgeu [SRC1], [SRC2], [IMM] | pc += (unsigned(SRC1) >= unsigned(SRC2)) ? (SE(12b immediate) * 2B) : 4B
```

### Conditional control flow: `immediate`, `branch`, `compressed`
Immediate bits are often not in order
```
 Binary             |  Instruction         |  Operation
110I IISS SIII II01 | c.beqz [SRC'], [IMM] | pc += (SRC' == 0) ? (SE(8b immediate) * 2B) : 2B
111I IISS SIII II01 | c.bnez [SRC'], [IMM] | pc += (SRC' != 0) ? (SE(8b immediate) * 2B) : 2B
```

## Load/Store
### Load/Store: `immediate`, `memory`
Immediate bits are often not in order
```
 Instruction             |  Operation
lw  [DEST], [IMM]([SRC]) | DEST =      MEM[SRC + SE(12b immediate), 32b]
lh  [DEST], [IMM]([SRC]) | DEST =   SE(MEM[SRC + SE(12b immediate), 16b])
lhu [DEST], [IMM]([SRC]) | DEST = {'0, MEM[SRC + SE(12b immediate), 16b]}
lb  [DEST], [IMM]([SRC]) | DEST =   SE(MEM[SRC + SE(12b immediate),  8b])
lbu [DEST], [IMM]([SRC]) | DEST = {'0, MEM[SRC + SE(12b immediate),  8b]}
sw  [SRC], [IMM]([DEST]) | MEM[DEST + SE(12b immediate), 32b] = SRC
sh  [SRC], [IMM]([DEST]) | MEM[DEST + SE(12b immediate), 16b] = SRC[15:0]
sb  [SRC], [IMM]([DEST]) | MEM[DEST + SE(12b immediate),  8b] = SRC[ 7:0]
```

### Load/Store: `immediate`, `memory`, `compressed`
Immediate bits are often not in order
```
 Binary             |  Instruction                 |  Operation                                             |  Notes
010I DDDD DIII II10 | c.lwsp  [DEST], [IMM]        | DEST  = MEM[sp   + (unsigned(6b immediate) * 4B), 32b] | DEST cannot be x0
010I IISS SIID DD00 | c.lw    [DEST'], [IMM](SRC') | DEST' = MEM[SRC' + (unsigned(6b immediate) * 4B), 32b]
110I IIII ISSS SS10 | c.swsp  [SRC], [IMM]         | MEM[sp    + (unsigned(6b immediate) * 4B), 32b] = SRC
110I IIDD DIIS SS00 | c.sw    [SRC'], [IMM](DEST') | MEM[DEST' + (unsigned(6b immediate) * 4B), 32b] = SRC'
```

## Notes

> There's fence, ecall, ebreak, c.ebreak, (and hint) too but I'm pretending those doesn't exist

Instructions with all bits zero, or all bits one, are reserved as illegal instructions
