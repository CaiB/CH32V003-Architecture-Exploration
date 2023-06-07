## Byte Operations
### xw.c.lbusp: Load Unsigned Byte at address relative to SP
```
100xxxxxxxxxxx00 is reserved
1000000000011100 801C "lbu a5,0(sp)"
1000000000000000 8000 "lbu s0,0(sp)"
1000000010000000 8080 "lbu s0,1(sp)"
1000000100000000 8100 "lbu s0,2(sp)"
1000001000000000 8200 "lbu s0,4(sp)"
1000010000000000 8400 "lbu s0,8(sp)"
1000011110000000 8780 "lbu s0,15(sp)"

10000IIII00DDD00
     3210 imm bits

Presumably DEST' = MEM[sp + (unsiged(4b immediate) * ???), 8b]
```

### xw.c.sbsp: Store Byte at address relative to SP
```
1000000001011100 805C "sb a5,0(sp)"
1000000001000000 8040 "sb s0,0(sp)"
1000000011000000 80C0 "sb s0,1(sp)"
1000000101000000 8140 "sb s0,2(sp)"
1000001001000000 8240 "sb s0,4(sp)"
1000010001000000 8440 "sb s0,8(sp)"
1000011111000000 87C0 "sb s0,15(sp)"

10000IIII10SSS00
     3210 imm bits

Presumably MEM[sp + (unsigned(4b immediate) * ???), 8b] = SRC'
```

### xw.c.lbu: Load Unsigned Byte
```
0010000000000000 2000 "lbu s0,0(s0)"
0010000000011100 201C "lbu a5,0(s0)"
0010001110000000 2380 "lbu s0,0(a5)"
0011000000000000 3000 "lbu s0,1(s0)"
0011000000000000 3000 "lbu s0,1(s0)"
0010000000100000 2020 "lbu s0,2(s0)"
0010000001000000 2040 "lbu s0,4(s0)"
0010010000000000 2400 "lbu s0,8(s0)"
0010100000000000 2800 "lbu s0,16(s0)"
0011110001100000 3C60 "lbu s0,31(s0)"

001IIISSSIIDDD00
   043   21 imm bits

Presumably DEST' = MEM[SRC' + (unsiged(5b immediate) * ???), 8b]
```

### xw.c.sb: Store Byte
```
1010000000011100 A01C "sb a5,0(s0)"
1010001110000000 A380 "sb s0,0(a5)"
1010000000000000 A000 "sb s0,0(s0)"
1011000000000000 B000 "sb s0,1(s0)"
1010000000100000 A020 "sb s0,2(s0)"
1010000001000000 A040 "sb s0,4(s0)"
1010010000000000 A400 "sb s0,8(s0)"
1010100000000000 A800 "sb s0,16(s0)"
1011110001100000 BC60 "sb s0,31(s0)"

101IIIDDDIISSS00
   043   21 imm bits

Presumably MEM[DEST' + (unsigned(5b immediate) * ???), 8b] = SRC'
```

## Half Instructions
### xw.c.lhusp: Load Unsigned Half at address relative to SP
```
1000000000111100 803C "lhu a5,0(sp)"
1000000000100000 8020 "lhu s0,0(sp)"
1000000100100000 8120 "lhu s0,2(sp)"
1000001000100000 8220 "lhu s0,4(sp)"
1000010000100000 8420 "lhu s0,8(sp)"
1000000010100000 80A0 "lhu s0,16(sp)"
1000011110100000 87A0 "lhu s0,30(sp)"

10000IIII01DDD00
     2103 imm bits

Presumably DEST' = MEM[sp + (unsiged(4b immediate) * ???), 16b]
```

### xw.c.shsp: Store Half at address relative to SP
```
1000000001111100 807C "sh a5,0(sp)"
1000000001100000 8060 "sh s0,0(sp)"
1000000101100000 8160 "sh s0,2(sp)"
1000001001100000 8260 "sh s0,4(sp)"
1000010001100000 8460 "sh s0,8(sp)"
1000000011100000 80E0 "sh s0,16(sp)"
1000011111100000 87E0 "sh s0,30(sp)"

10000IIII11SSS00
     2103 imm bits

Presumably MEM[sp + (unsigned(4b immediate) * ???), 16b] = SRC'
```

### xw.c.lhu: Load Unsigned Half
```
0010000000000010 2002 "lhu s0,0(s0)"
0010001110000010 2382 "lhu s0,0(a5)"
0010000000011110 201E "lhu a5,0(s0)"
0010000000100010 2022 "lhu s0,2(s0)"
0010000001000010 2042 "lhu s0,4(s0)"
0010010000000010 2402 "lhu s0,8(s0)"
0010100000000010 2802 "lhu s0,16(s0)"
0011000000000010 3002 "lhu s0,32(s0)"
0011110001100010 3C62 "lhu s0,62(s0)"

001IIISSSIIDDD10
   432   10 imm bits

Presumably DEST' = MEM[SRC' + (unsiged(5b immediate) * ???), 16b]
```

### xw.c.sh: Store Half
```
1010000000011110 A01E "sh a5,0(s0)"
1010001110000010 A382 "sh s0,0(a5)"
1010000000000010 A002 "sh s0,0(s0)"
1010000000100010 A022 "sh s0,2(s0)"
1010000001000010 A042 "sh s0,4(s0)"
1010010000000010 A402 "sh s0,8(s0)"
1010100000000010 A802 "sh s0,16(s0)"
1011000000000010 B002 "sh s0,32(s0)"
1011110001100010 BC62 "sh s0,62(s0)"

101IIIDDDIISSS10
   432   10 imm bits

Presumably MEM[DEST' + (unsigned(5b immediate) * ???), 16b] = SRC'
```