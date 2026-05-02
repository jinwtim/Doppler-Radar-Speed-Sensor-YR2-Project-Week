/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  */
/* USER CODE END Header */
#include "main.h"
#include "adc.h"
#include "comp.h"
#include "dma.h"
#include "tim.h"
#include "usart.h"
#include "gpio.h"

/* USER CODE BEGIN Includes */
#include <stdio.h>
#include <string.h>
#include "adc.h"
#include "comparator.h"
#include "display.h"
#include "processing.h"
/* USER CODE END Includes */

/* USER CODE BEGIN PD */
#define COMP_OUT_Pin        GPIO_PIN_5
#define COMP_OUT_GPIO_Port  GPIOC
#define RADAR_FREQUENCY_HZ  10.525e9f
#define SPEED_OF_LIGHT      299792458.0f
/* USER CODE END PD */

/* USER CODE BEGIN PV */
float speed_mps       = 0.0f;
float frequency_hz    = 0.0f;
float fft_frequency_hz = 0.0f;
float fft_speed_mps   = 0.0f;
float voltage         = 0.0f;

uint16_t adc_buffer[FFT_SIZE];
uint16_t processing_buffer[FFT_SIZE];
volatile uint8_t  data_full_ready_flag = 0;
volatile uint32_t fft_run_count        = 0;
volatile uint32_t dma_error_count      = 0;

uint32_t last_uart_tick    = 0;
uint32_t last_display_tick = 0;
const uint32_t uart_interval_ms    = 50;
const uint32_t display_interval_ms = 100;

#define VOLTAGE_BUFFER_SIZE 16
float    voltage_buffer[VOLTAGE_BUFFER_SIZE] = {0};
uint8_t  voltage_buffer_index  = 0;
uint8_t  voltage_buffer_filled = 0;
uint32_t display_read_index    = 0;
/* USER CODE END PV */

void SystemClock_Config(void);
void PeriphCommonClock_Config(void);

int main(void)
{
    HAL_Init();
    SystemClock_Config();
    PeriphCommonClock_Config();

    MX_GPIO_Init();
    MX_DMA_Init();
    MX_COMP1_Init();
    MX_ADC3_Init();
    MX_ADC2_Init();
    MX_TIM2_Init();
    MX_UART4_Init();

    /* USER CODE BEGIN 2 */
    HAL_ADCEx_Calibration_Start(&hadc3, ADC_SINGLE_ENDED);
    HAL_COMP_Start(&hcomp1);
    Display_Init(&hadc2);
    Comparator_Init_EdgeCounting();
    Processing_Init();

    if (HAL_ADC_Start_DMA(&hadc3, (uint32_t*)adc_buffer, FFT_SIZE) != HAL_OK)
        Error_Handler();
    if (HAL_TIM_Base_Start(&htim2) != HAL_OK)
        Error_Handler();
    /* USER CODE END 2 */

    while (1)
    {
        /* --- Task 7: Comparator --- */
        uint8_t compState = HAL_COMP_GetOutputLevel(&hcomp1);
        Comparator_Update_EdgeCount(compState);

        if (Comparator_Calculate_Frequency() == 1)
        {
            speed_mps    = Comparator_Calculate_Speed();
            frequency_hz = Comparator_Get_Frequency();
            if (frequency_hz > 1000.0f) frequency_hz = 1000.0f;
        }

        /* --- Task 8: FFT --- */
        if (data_full_ready_flag)
        {
            data_full_ready_flag = 0;
            fft_run_count++;

            memcpy(processing_buffer, adc_buffer, FFT_SIZE * sizeof(uint16_t));

            fft_frequency_hz = Processing_Calculate_FFT(processing_buffer);
            if (fft_frequency_hz > 1000.0f) fft_frequency_hz = 1000.0f;

            fft_speed_mps = (fft_frequency_hz * SPEED_OF_LIGHT) / (2.0f * RADAR_FREQUENCY_HZ);

            for (uint32_t i = 0; i < VOLTAGE_BUFFER_SIZE && i < FFT_SIZE; i++)
            {
                uint32_t sample_idx = (i * FFT_SIZE) / VOLTAGE_BUFFER_SIZE;
                voltage_buffer[i] = 3.3f * processing_buffer[sample_idx] / 4095.0f;
            }
            voltage_buffer_filled = 1;
            display_read_index    = 0;
        }

        /* --- Timed UART Update (Serial Plotter) --- */
        uint32_t current_tick = HAL_GetTick();

        if (current_tick - last_uart_tick >= uart_interval_ms)
        {
            last_uart_tick = current_tick;

            if (voltage_buffer_filled)
            {
                voltage = voltage_buffer[display_read_index];
                display_read_index = (display_read_index + 1) % VOLTAGE_BUFFER_SIZE;
            }
            else
            {
                uint32_t dma_remaining = __HAL_DMA_GET_COUNTER(hadc3.DMA_Handle);
                uint32_t write_pos = (FFT_SIZE - dma_remaining) % FFT_SIZE;
                uint32_t read_pos  = (write_pos + FFT_SIZE - 50) % FFT_SIZE;
                voltage = 3.3f * adc_buffer[read_pos] / 4095.0f;
            }

            // Uncomment to send plotter data
            // char msg[80];
            // sprintf(msg, "%.3f,%lu,%.1f,%.1f\n", voltage, Comparator_Get_EdgeCount(), frequency_hz, fft_frequency_hz);
            // HAL_UART_Transmit(&huart2, (uint8_t*)msg, strlen(msg), HAL_MAX_DELAY);
        }

        /* --- Timed Display Update (LCD & RS485 CPLD) --- */
        if (current_tick - last_display_tick >= display_interval_ms)
        {
            last_display_tick = current_tick;

            // 1. Update onboard LCD (this also handles button presses / unit switching)
            Display_Update(fft_speed_mps, voltage, fft_frequency_hz);

            // 2. RS485 CPLD Display Update
            // Read whichever unit the LCD is currently showing and match it
            float speed_display = 0.0f;

            switch (Display_GetUnit())
            {
                case UNIT_KMH:
                    speed_display = fft_speed_mps * 3.6f;
                    break;
                case UNIT_MPH:
                    speed_display = fft_speed_mps * 2.23694f;
                    break;
                case UNIT_MS:
                default:
                    speed_display = fft_speed_mps;
                    break;
            }

            // Cap at 99 (two digits only on 7-segment)
            uint8_t speed_int = (uint8_t)speed_display;
            if (speed_int > 99) speed_int = 99;

            // Pack as BCD: [7:4] = tens, [3:0] = units
            uint8_t bcd_speed = ((speed_int / 10) << 4) | (speed_int % 10);

            // Send to CPLD via RS485 UART4
            HAL_UART_Transmit(&huart4, &bcd_speed, 1, 10);
        }
    }
}

void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct = {0};
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

    if (HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1) != HAL_OK)
        Error_Handler();

    RCC_OscInitStruct.OscillatorType      = RCC_OSCILLATORTYPE_HSI;
    RCC_OscInitStruct.HSIState            = RCC_HSI_ON;
    RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
    RCC_OscInitStruct.PLL.PLLState        = RCC_PLL_ON;
    RCC_OscInitStruct.PLL.PLLSource       = RCC_PLLSOURCE_HSI;
    RCC_OscInitStruct.PLL.PLLM            = 1;
    RCC_OscInitStruct.PLL.PLLN            = 10;
    RCC_OscInitStruct.PLL.PLLP            = RCC_PLLP_DIV7;
    RCC_OscInitStruct.PLL.PLLQ            = RCC_PLLQ_DIV2;
    RCC_OscInitStruct.PLL.PLLR            = RCC_PLLR_DIV2;
    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
        Error_Handler();

    RCC_ClkInitStruct.ClockType      = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
                                     | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    RCC_ClkInitStruct.SYSCLKSource   = RCC_SYSCLKSOURCE_PLLCLK;
    RCC_ClkInitStruct.AHBCLKDivider  = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;
    if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_4) != HAL_OK)
        Error_Handler();
}

void PeriphCommonClock_Config(void)
{
    RCC_PeriphCLKInitTypeDef PeriphClkInit = {0};

    PeriphClkInit.PeriphClockSelection        = RCC_PERIPHCLK_ADC;
    PeriphClkInit.AdcClockSelection           = RCC_ADCCLKSOURCE_PLLSAI1;
    PeriphClkInit.PLLSAI1.PLLSAI1Source       = RCC_PLLSOURCE_HSI;
    PeriphClkInit.PLLSAI1.PLLSAI1M            = 1;
    PeriphClkInit.PLLSAI1.PLLSAI1N            = 8;
    PeriphClkInit.PLLSAI1.PLLSAI1P            = RCC_PLLP_DIV7;
    PeriphClkInit.PLLSAI1.PLLSAI1Q            = RCC_PLLQ_DIV2;
    PeriphClkInit.PLLSAI1.PLLSAI1R            = RCC_PLLR_DIV2;
    PeriphClkInit.PLLSAI1.PLLSAI1ClockOut     = RCC_PLLSAI1_ADC1CLK;
    if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK)
        Error_Handler();
}

/* USER CODE BEGIN 4 */
void HAL_DMA_ErrorCallback(DMA_HandleTypeDef *hdma)
{
    if (hdma == hadc3.DMA_Handle)
    {
        dma_error_count++;
        HAL_TIM_Base_Stop(&htim2);
        HAL_ADC_Stop_DMA(&hadc3);
        HAL_ADCEx_Calibration_Start(&hadc3, ADC_SINGLE_ENDED);
        if (HAL_ADC_Start_DMA(&hadc3, (uint32_t*)adc_buffer, FFT_SIZE) != HAL_OK)
            Error_Handler();
        if (HAL_TIM_Base_Start(&htim2) != HAL_OK)
            Error_Handler();
    }
}

void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef* hadc)
{
    if (hadc->Instance == ADC3)
        data_full_ready_flag = 1;
}
/* USER CODE END 4 */

void Error_Handler(void) {}

#ifdef USE_FULL_ASSERT
void assert_failed(uint8_t *file, uint32_t line) {}
#endif
