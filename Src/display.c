/*
 * display.c
 */

#include "display.h"
#include "lcd16x2.h"
#include <stdio.h>
#include <string.h>

#define BTN_RIGHT_THRESHOLD     400
#define BTN_UP_THRESHOLD        1300
#define BTN_DOWN_THRESHOLD      2300
#define BTN_LEFT_THRESHOLD      3400

typedef enum {
    BTN_NONE,
    BTN_RIGHT,
    BTN_UP,
    BTN_DOWN,
    BTN_LEFT
} ButtonType;

static ADC_HandleTypeDef* button_adc_handle;
static SpeedUnit currentUnit = UNIT_MS;
static uint8_t buttonWasPressed = 0;

static ButtonType Read_Keypad_Button(void);

/**
 * @brief Returns the currently selected speed unit.
 *        Used by main.c to match the 7-segment display to the LCD.
 */
SpeedUnit Display_GetUnit(void)
{
    return currentUnit;
}

void Display_Init(ADC_HandleTypeDef* adc_handle)
{
    button_adc_handle = adc_handle;

    HAL_GPIO_WritePin(D10_GPIO_Port, D10_Pin, GPIO_PIN_SET);
    lcd16x2_init_4bits(RS_GPIO_Port, RS_Pin, E_GPIO_Port, E_Pin,
                       D4_GPIO_Port, D4_Pin, D5_GPIO_Port, D5_Pin,
                       D6_GPIO_Port, D6_Pin, D7_GPIO_Port, D7_Pin);
}

void Display_Update(float speed_mps, float voltage, float frequency_hz)
{
    /* --- 1. Read Buttons and Update State --- */
    ButtonType pressedButton = Read_Keypad_Button();

    if (pressedButton != BTN_NONE && buttonWasPressed == 0)
    {
        buttonWasPressed = 1;

        if (pressedButton == BTN_RIGHT)
        {
            if (currentUnit == UNIT_MS)       currentUnit = UNIT_KMH;
            else if (currentUnit == UNIT_KMH) currentUnit = UNIT_MPH;
            else if (currentUnit == UNIT_MPH) currentUnit = UNIT_MS;
        }
        else if (pressedButton == BTN_LEFT)
        {
            if (currentUnit == UNIT_MS)       currentUnit = UNIT_MPH;
            else if (currentUnit == UNIT_MPH) currentUnit = UNIT_KMH;
            else if (currentUnit == UNIT_KMH) currentUnit = UNIT_MS;
        }
    }
    else if (pressedButton == BTN_NONE)
    {
        buttonWasPressed = 0;
    }

    /* --- 2. Prepare Data for Display --- */
    float displaySpeed = speed_mps;
    char unitString[5];

    if (currentUnit == UNIT_KMH)
    {
        displaySpeed = speed_mps * 3.6f;
        strcpy(unitString, "km/h");
    }
    else if (currentUnit == UNIT_MPH)
    {
        displaySpeed = speed_mps * 2.23694f;
        strcpy(unitString, "mph");
    }
    else
    {
        displaySpeed = speed_mps;
        strcpy(unitString, "m/s");
    }

    /* --- 3. Print to LCD --- */
    lcd16x2_clear();

    lcd16x2_1stLine();
    lcd16x2_printf("V:%.2fV F:%.0fHz", voltage, frequency_hz);

    lcd16x2_2ndLine();
    lcd16x2_printf("Speed: %.2f %s", displaySpeed, unitString);
}

static ButtonType Read_Keypad_Button(void)
{
    uint32_t adcVal = 0;

    HAL_ADC_Start(button_adc_handle);
    HAL_ADC_PollForConversion(button_adc_handle, HAL_MAX_DELAY);
    adcVal = HAL_ADC_GetValue(button_adc_handle);
    HAL_ADC_Stop(button_adc_handle);

    if (adcVal < BTN_RIGHT_THRESHOLD) return BTN_RIGHT;
    if (adcVal < BTN_UP_THRESHOLD)    return BTN_UP;
    if (adcVal < BTN_DOWN_THRESHOLD)  return BTN_DOWN;
    if (adcVal < BTN_LEFT_THRESHOLD)  return BTN_LEFT;

    return BTN_NONE;
}
