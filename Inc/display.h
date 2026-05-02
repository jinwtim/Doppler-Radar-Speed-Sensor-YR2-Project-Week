/*
 * display.h
 */

#ifndef INC_DISPLAY_H_
#define INC_DISPLAY_H_

#include "main.h"

// Speed unit enum - exposed so main.c can read it
typedef enum {
    UNIT_MS,
    UNIT_KMH,
    UNIT_MPH
} SpeedUnit;

void Display_Init(ADC_HandleTypeDef* adc_handle);
void Display_Update(float speed_mps, float voltage, float frequency_hz);
SpeedUnit Display_GetUnit(void);   // <-- NEW: lets main.c read current unit

#endif /* INC_DISPLAY_H_ */
