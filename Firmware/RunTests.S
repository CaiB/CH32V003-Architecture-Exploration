#define ASSEMBLER
#include "ch32v003fun.h"
#include "Firmware.h"
#define BSHR_OFFSET 16
#define INDR_OFFSET 8
#define SYSTICK_CNT 0xE000F008

#define PIN_OFF li a1, 1 << (16 + OUT_PIN); sw a1, BSHR_OFFSET(a0)
#define PIN_ON li a1, 1 << OUT_PIN; sw a1, BSHR_OFFSET(a0)

//.global EXTI7_0_IRQHandler
//EXTI7_0_IRQHandler:
.global RunTests
RunTests:
    // Push registers onto stack
    //addi    sp, sp, -44
    //sw      a0, 0(sp)
    //sw      a1, 4(sp)

    // Prep
    la      a0, GPIOD_BASE
    PIN_OFF
    nop; nop; nop; nop; nop; nop; nop; nop // x8

    // Output a few pulses (alignment? who needs it)
    PIN_ON
    PIN_OFF
    nop; nop; nop; nop
    
    PIN_ON
    nop
    PIN_OFF
    nop; nop; nop; nop

    PIN_ON
    nop; nop
    PIN_OFF
    nop; nop; nop; nop

    PIN_ON
    nop; nop; nop; nop
    PIN_OFF

    // Acknowledge the interrupt
    //la      a0, EXTI_BASE + 20 // EXTI->INTFR
    //li      a1, (1 << IN_PIN)
    //sw      a1, 0(a0)

    // Restore registers from stack
    //lw      a0, 0(sp)
    //lw      a1, 4(sp)
    //addi    sp, sp, 44
	//mret
    ret
    