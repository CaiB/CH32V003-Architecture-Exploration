#include "ch32fun.h"
#include "Firmware.h"
#define BSHR_OFFSET 16
#define INDR_OFFSET 8
#define SYSTICK_CNT 0xE000F008

#define PIN_OFF_A sw a1, BSHR_OFFSET(a0)
#define PIN_ON_A sw a2, BSHR_OFFSET(a0)

#define PIN_OFF_B li a1, 1 << (16 + OUT_PIN_B); sw a1, BSHR_OFFSET(a0)
#define PIN_ON_B li a1, 1 << OUT_PIN_B; sw a1, BSHR_OFFSET(a0)

.global RunTests
RunTests:
    // Prep
    la      a0, GPIOD_BASE
    li      a1, 1 << (16 + OUT_PIN_A) // A off *KEEP THIS*
    li      a2, 1 << OUT_PIN_A // A on *KEEP THIS*
    li      a3, 1 << OUT_PIN_B // B on
    PIN_OFF_A
    nop; nop; nop; nop; nop; nop; nop; // x7

    // Output a few pulses
    .balign 32 // Let's be extra generous
    nop
    nop // Make sure instructions are fetched
    sw a3, BSHR_OFFSET(a0) // B on (can delete a3 now)
    PIN_ON_A
    PIN_OFF_A
    nop; nop; nop; nop;
    
    PIN_ON_A
    nop
    PIN_OFF_A
    nop; nop; nop; nop;

    PIN_ON_A
    nop; nop
    PIN_OFF_A
    nop; nop; nop; nop;

    PIN_ON_A
    nop; nop; nop; nop;
    PIN_OFF_A

    ret
    