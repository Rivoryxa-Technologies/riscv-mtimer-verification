/* sw/mtimer_driver.h
 * The only code in the firmware that writes the mtimer div register.
 * div = clk_hz / tick_hz, using C unsigned integer division.
 */
#ifndef MTIMER_DRIVER_H
#define MTIMER_DRIVER_H

#include <stdint.h>
#include "board_limits.h"

#define MTIMER_REG_MTIME    0u
#define MTIMER_REG_MTIMECMP 1u
#define MTIMER_REG_DIV      2u

#if BOARD_CLK_HZ < MTIMER_CLK_HZ_MIN || BOARD_CLK_HZ > MTIMER_CLK_HZ_MAX
#error "BOARD_CLK_HZ is outside the supported mtimer clock range"
#endif
#if BOARD_TICK_HZ < MTIMER_TICK_HZ_MIN || BOARD_TICK_HZ > MTIMER_TICK_HZ_MAX
#error "BOARD_TICK_HZ is outside the supported mtime tick range"
#endif

static inline void mtimer_init(void (*write_reg)(uint32_t addr, uint64_t value))
{
    write_reg(MTIMER_REG_DIV, (uint64_t)(BOARD_CLK_HZ / BOARD_TICK_HZ));
}

#endif
