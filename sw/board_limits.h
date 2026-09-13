/* sw/board_limits.h
 * Clock limits for every board this firmware supports. The build refuses a board
 * whose clock settings fall outside these ranges (see mtimer_driver.h).
 */
#ifndef BOARD_LIMITS_H
#define BOARD_LIMITS_H

#define MTIMER_CLK_HZ_MIN    1000000u    /*   1 MHz timer input clock */
#define MTIMER_CLK_HZ_MAX  100000000u    /* 100 MHz timer input clock */
#define MTIMER_TICK_HZ_MIN     10000u    /*  10 kHz mtime tick rate   */
#define MTIMER_TICK_HZ_MAX   1000000u    /*   1 MHz mtime tick rate   */

#endif
