#define SYSTEM_CORE_CLOCK 48000000
#define SYSTICK_USE_HCLK

#include "ch32v003fun.h"
#include "Firmware.h"

// PINS USED:
// System clock: PC4 (fixed)
// Input trigger: PD4
// Output: PD2
// Can change these in Firmware.h

void RunTests();

int main()
{
    SystemInit48HSI();
	SetupDebugPrintf();
	SETUP_SYSTICK_HCLK
    
	// Enable GPIOs, DMA and TIMERs
	RCC->AHBPCENR = RCC_AHBPeriph_SRAM | RCC_AHBPeriph_DMA1;
	RCC->APB2PCENR = RCC_APB2Periph_GPIOD | RCC_APB2Periph_GPIOC | RCC_APB2Periph_TIM1 | RCC_APB2Periph_GPIOA | RCC_APB2Periph_AFIO;

	// Output the 48MHz system clock (MSO) to PC4 for counting cycles with
	GPIOC->CFGLR &= ~(GPIO_CFGLR_MODE4 | GPIO_CFGLR_CNF4);
	GPIOC->CFGLR |= GPIO_CFGLR_CNF4_1 | GPIO_CFGLR_MODE4_0 | GPIO_CFGLR_MODE4_1;
	RCC->CFGR0 = (RCC->CFGR0 & ~RCC_CFGR0_MCO) | RCC_CFGR0_MCO_SYSCLK;

	// Enable the GPIO pins on port D
	GPIOD->CFGLR =
		(GPIO_CNF_IN_PUPD) << 4 |  // Keep SWIO enabled.
		(GPIO_Speed_50MHz | GPIO_CNF_OUT_PP) << (4 * OUT_PIN)
	  | (GPIO_SPEED_IN | GPIO_CNF_IN_PUPD) << (4 * IN_PIN);
	//| (GPIO_SPEED_IN | GPIO_CNF_IN_PUPD) << (4 * [PIN_DEFN]) // <--- Use lines like this to enable additional pins on the D port

	// Configure IN_PIN as an interrupt.
	//AFIO->EXTICR = 3 << (IN_PIN * 2); // 3 in front = PORTD
	//EXTI->INTENR = 1 << IN_PIN; // Enable EXT3
	//EXTI->FTENR = 1 << IN_PIN;  // Rising edge trigger

	// Disable fast interrupts. "HPE"
	asm volatile("addi t1,x0, 0\ncsrrw x0, 0x804, t1\n" : : :  "t1");

	// Enable interrupt
	//NVIC_EnableIRQ(EXTI7_0_IRQn);

	while(1)
	{
		asm volatile( "nop \n nop \n nop \n nop \n");
		if ((*DMDATA0) == 0x444F)
		{
			RunTests();
			(*DMDATA0) = 0x4F4B;
		}
	}
}