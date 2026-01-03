
/***********************************************************************************************************************
 * File Name    : i2c_api_icm42670.h
 * Created on   : 22.05.2024
 * Description  : Contains UART functions definition.
 **********************************************************************************************************************/
/***********************************************************************************************************************
 * Copyright [2020-2024] Renesas Electronics Corporation and/or its affiliates.  All Rights Reserved.
 *
 * This software and documentation are supplied by Renesas Electronics America Inc. and may only be used with products
 * of Renesas Electronics Corp. and its affiliates ("Renesas").  No other uses are authorized.  Renesas products are
 * sold pursuant to Renesas terms and conditions of sale.  Purchasers are solely responsible for the selection and use
 * of Renesas products and Renesas assumes no liability.  No license, express or implied, to any intellectual property
 * right is granted by Renesas. This software is protected under all applicable laws, including copyright laws. Renesas
 * reserves the right to change or discontinue this software and/or this documentation. THE SOFTWARE AND DOCUMENTATION
 * IS DELIVERED TO YOU "AS IS," AND RENESAS MAKES NO REPRESENTATIONS OR WARRANTIES, AND TO THE FULLEST EXTENT
 * PERMISSIBLE UNDER APPLICABLE LAW, DISCLAIMS ALL WARRANTIES, WHETHER EXPLICITLY OR IMPLICITLY, INCLUDING WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT, WITH RESPECT TO THE SOFTWARE OR
 * DOCUMENTATION.  RENESAS SHALL HAVE NO LIABILITY ARISING OUT OF ANY SECURITY VULNERABILITY OR BREACH.  TO THE MAXIMUM
 * EXTENT PERMITTED BY LAW, IN NO EVENT WILL RENESAS BE LIABLE TO YOU IN CONNECTION WITH THE SOFTWARE OR DOCUMENTATION
 * (OR ANY PERSON OR ENTITY CLAIMING RIGHTS DERIVED FROM YOU) FOR ANY LOSS, DAMAGES, OR CLAIMS WHATSOEVER, INCLUDING,
 * WITHOUT LIMITATION, ANY DIRECT, CONSEQUENTIAL, SPECIAL, INDIRECT, PUNITIVE, OR INCIDENTAL DAMAGES; ANY LOST PROFITS,
 * OTHER ECONOMIC DAMAGE, PROPERTY DAMAGE, OR PERSONAL INJURY; AND EVEN IF RENESAS HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH LOSS, DAMAGES, CLAIMS OR COSTS.
 **********************************************************************************************************************/


#ifndef I2C_DEVICE_ICM42670_I2C_API_ICM42670_H_
#define I2C_DEVICE_ICM42670_I2C_API_ICM42670_H_

#include "hal_data.h"
#include "rm_icm42670_type.h"

/** ICM42670 raw data structure */
typedef struct
{
    uint8_t reg_data[20];              ///< data read from sensor register
} i2c_api_icm42670_raw_data_t;

/* ICM42670 accelerator data structure */
typedef struct
{
    float accel_x;              ///< X_Axis Accelerometer data (16bits).
    float accel_y;              ///< Y_Axis Accelerometer data (16bits).
    float accel_z;              ///< Z_Axis Accelerometer data (16bits).
} i2c_api_icm42670_accel_data_t;

/* ICM42670 accel data structure */
typedef struct
{
    float gyro_x;               ///< X_Axis Gyroscope data (16bits).
    float gyro_y;               ///< Y_Axis Gyroscope data (16bits).
    float gyro_z;               ///< Z_Axis Gyroscope data (16bits).
} i2c_api_icm42670_gyro_data_t;

/* ICM42670 temp data structure */
typedef struct
{
    int16_t temp_data;          ///< Temperature compensation  channel data (16bits).
    float temp_data_float;      ///< Temperature compensation  channel data (float).
} i2c_api_icm42670_temp_data_t;


/** ICM42670 FIFO information structure */
typedef struct
{
    uint8_t write_index;               ///< The FIFO index where the next sample of PPG data will be written in the FIFO.
    uint8_t read_index;                ///< The index of the next sample to be read from the FIFO_DATA register.
    uint8_t overflow_counter;          ///< If the FIFO Rollover Enable bit is set, the FIFO overflow counter counts the number of old samples (up to 15) which are overwritten by new data.
    uint8_t unread_samples;            ///< The number of unread samples calculated from the write index and the read index.
} i2c_api_icm42670_fifo_info_t;

/* sensor control structure */
typedef struct
{
    uint16_t                             accel_sensitivity_shift;  // Accelerator Sensitivity Scale Factor Shift.
    uint16_t                             gyro_sensitivity_x10;     // Gyroscope  Sensitivity Scale Factor * 10.
    uint8_t                              ioBbuffer[8];             // Buffer for I2C communications
    uint8_t                              register_address;         // Register address to access
    uint8_t                              spare;                    // unused
    uint8_t                              who_am_i;                 // device rerurn ID
    bool                                 isOpen;                   // Open flag
    bool                                 fifo_reset;               // FIFO status
    bool                                 interrupt_bits_clear;     // interrupt status
 } i2c_api_icm42670_device_ctrl_t;


 typedef struct st_rm_icm42670_device_interrupt_cfg
 {
     rm_icm42670_operation_interrupt_type_t     int_type;     ///< interrupt type: INT1, INT2, INT1&INT2
     rm_icm42670_interrupt_source_t             int_source;   ///<  interrupt source.
     uint8_t                                    int_config;   ///< INT_CONFIG (register 0x06 of Bank0, include mode,drive chain,polarity of INT1 and INT2.
 } i2c_api_icm42670_device_interrupt_cfg_t;


 /** ICM42670 device status */
 typedef struct
 {
     bool data_ready;

     bool agc_ready;
     bool fifo_afull_int_occur;   ///< FIFO almost full interrupt
     bool fifo_ths_int_occur;   ///< FIFO threshold interrupt
     bool power_on_reset_occur;
     bool pll_ready;
     bool FSYNC_int_occur;
     bool self_test_done;   //: Self-Test Done

     bool wom_z_occur;
     bool wom_y_occur;
     bool wom_x_occur;
     bool SMD_occur;

     bool lowG_occur;
     bool freefall_occur;
     bool tilt_detection;
     bool step_count_overflow_occur;
     bool step_detection;
 } i2c_api_icm42670_device_status_t;

 // function
 extern volatile bool g_i2c_api_irq_flag;

 // function definitions
 unsigned char i2c_api_icm42670_get_who_am_i( void );
 fsp_err_t i2c_api_icm42670_open ( void );
 fsp_err_t i2c_api_icm42670_close ( void );
 fsp_err_t i2c_api_icm42670_measurementStart( void );
 fsp_err_t i2c_api_icm42670_deviceStatusGet( i2c_api_icm42670_device_status_t * const p_status );
 fsp_err_t i2c_api_icm42670_tempRead ( i2c_api_icm42670_raw_data_t * const p_raw_data);
 fsp_err_t i2c_api_icm42670_tempDataCalculate ( i2c_api_icm42670_raw_data_t * const p_raw_data, i2c_api_icm42670_temp_data_t * const p_icm42670_data,
                                                int16_t offset);
 fsp_err_t i2c_api_icm42670_accelRead( i2c_api_icm42670_raw_data_t * const p_raw_data);
 fsp_err_t i2c_api_icm42670_accelDataCalculate (  i2c_api_icm42670_raw_data_t * const p_raw_data, i2c_api_icm42670_accel_data_t * const p_icm42670_data);
 fsp_err_t i2c_api_icm42670_gyroRead (i2c_api_icm42670_raw_data_t * const p_raw_data);
 fsp_err_t i2c_api_icm42670_gyroDataCalculate (i2c_api_icm42670_raw_data_t * const  p_raw_data, i2c_api_icm42670_gyro_data_t * const p_icm42670_data);
 fsp_err_t i2c_api_icm42670_deviceInterruptCfgSet (i2c_api_icm42670_device_interrupt_cfg_t const interrupt_cfg);
 void i2c_api_icm42670_deviceInterruptCfgGet (i2c_api_icm42670_device_interrupt_cfg_t * p_interrupt_cfg);
 void i2c_api_icm42670_accel_setMode (rm_icm42670_accel_sensor_mode_t  accel_sensor_mode, int16_t  accel_fs, uint16_t accel_odr );

#endif /* I2C_DEVICE_ICM42670_I2C_API_ICM42670_H_ */
