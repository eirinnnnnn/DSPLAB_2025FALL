
/***********************************************************************************************************************
 * File Name    : i2c_io_icm42670.h
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


#ifndef I2C_DEVICE_ICM42670_I2C_IO_ICM42670_H_
#define I2C_DEVICE_ICM42670_I2C_IO_ICM42670_H_

#include "i2c_api_icm42670.h"
#include "rm_icm42670_reg.h"

/* Definitions of Timeout */
#define RM_ICM42670_TIMEOUT                      (10)
#define RM_ICM42670_10MS                         (10)

/* Definitions of Register data */
#define RM_ICM42670_REG_DATA_PPG_PS_GAIN         (0x09)

/* Definitions of Commands */
#define RM_ICM42670_COMMAND_SOFTWARE_RESET       (0x80)

/* Definitions of Register address */
#define RM_ICM42670_REG_ADDR_MCLK_RDY            (0x00) // 0: Indicates internal clock is currently not running;1: Indicates internal clock is currently running
#define RM_ICM42670_REG_ADDR_SIGNAL_PATH_RESET   (0x02) // SOFT_RESET_DEVICE_CONFIG & FIFO FLUSH
#define RM_ICM42670_REG_ADDR_INT_CONFIG          (0x06) // INT1,INT2 MODE,DRIVE CIRCUIT, POLARITY configure
#define RM_ICM42670_REG_ADDR_PWR_MGMT0           (0x1F) // Power mode set: accel mode, gyro mode, idle mode

#define RM_ICM42670_REG_ADDR_INT_STATUS          (0x39) // LS operation mode control, software (SW) reset

/* Definitions of INT Status Mask */
/* Definitions of INT_STATUS_DRDY(0x39) Mask */
#define RM_ICM42670_MASK_DATA_RDY_STATUS         (0x01)     //DATA_RDY_INT

/* Definitions of INT_STATUS(0x3A) Mask */
#define RM_ICM42670_MASK_AGC_RDY_STATUS          (0x01)
#define RM_ICM42670_MASK_FIFO_FULL_STATUS        (0x02)
#define RM_ICM42670_MASK_FIFO_THS_STATUS         (0x04)
#define RM_ICM42670_MASK_RESET_DONE              (0x10)
#define RM_ICM42670_MASK_PLL_RDY_STATUS          (0x20)
#define RM_ICM42670_MASK_FSYNC_STATUS            (0x40)
#define RM_ICM42670_MASK_ST_STATUS               (0x80)

/* Definitions of INT_STATUS2(0x3B) Mask */
#define RM_ICM42670_MASK_WOM_Z_STATUS            (0x01)
#define RM_ICM42670_MASK_WOM_Y_STATUS            (0x02)
#define RM_ICM42670_MASK_WOM_X_STATUS            (0x04)
#define RM_ICM42670_MASK_SMD_STATUS              (0x08)

/* Definitions of INT_STATUS3(0x3C) Mask */
#define RM_ICM42670_MASK_LOWG_DET_STATUS          (0x02)
#define RM_ICM42670_MASK_FF_DET_STATUS            (0x04)
#define RM_ICM42670_MASK_TILT_DET_STATUS          (0x08)
#define RM_ICM42670_MASK_STEP_CNT_OVF_STATUS      (0x10)
#define RM_ICM42670_MASK_STEP_DET_STATUS          (0x20)

/* Definitions of FIFO */
#define RM_ICM42670_FIFO_MAX_SAMPLES_1K          (1024) //1K
#define RM_ICM42670_FIFO_MAX_SAMPLES_EXPAND      (2304) //APEX disabled, FIFO expanded to 2.25K
#define RM_ICM42670_FIFO_MASK_PPG2_0XFE          (0xFE)

#define RM_ICM42670_SELECT_RC_OSC                (0x00)   ///< Always select internal RC oscillator.

// type definitions


/** ICM42670 extended configuration */
typedef struct
{
    // Common
    rm_icm42670_operation_interrupt_type_t  int_type;          ///< dtorage for interrupt type
    rm_icm42670_operation_mode_t     mode_irq;                 ///< Operation mode using IRQ
    rm_icm42670_interrupt_source_t   interrupt_source;         ///< Interrupt source.
    uint8_t                          interrupt_config;         ///< interrupt config of int1 and int2.
    rm_icm42670_pwr_rc_idle_t        pwr_rc_idle;              ///< INT_CONFIG0, Interrupt Clear Option (latched mode).
    rm_icm42670_clksel_t             clksel;                   ///< SIGNAL_PATH_RESET, Software Reset (auto clear bit).

    // Accel mode cfg
    rm_icm42670_accel_sensor_mode_t  accel_sensor_mode;        ///< LP or LN sensor mode
    int16_t                          accel_fs;                 ///< Full scale select for accelerometer UI interface output
    uint16_t                         accel_odr;                ///< Accelerometer ODR selection for UI interface output
    rm_icm42670_accel_lp_clk_sel_t   accel_lp_clk_sel;         ///< Accelerometer LP mode clk select
    rm_icm42670_accel_ui_filt_bw_t   accel_ui_filt_bw;         ///< Selects ACCEL UI low pass filter bandwidth
    rm_icm42670_accel_ui_avg_t       accel_ui_avg;             ///< Selects averaging filter setting to create accelerometer output in accelerometer low power mode (LPM)

    // Gyrocope mode cfg
    rm_icm42670_gyro_sensor_mode_t   gyro_sensor_mode;         ///< Gyroscope mode : standby or LN.
    int16_t                          gyro_fs;                  ///< Full scale select for gyroscope UI interface output
    uint16_t                         gyro_odr;                 ///< Gyroscope ODR selection for UI interface output
    rm_icm42670_gyro_ui_filt_bw_t    gyro_ui_filt_bw;          ///< Selects GYRO UI low pass filter bandwidth of ICM42670.

    //Temp config
    rm_icm42670_temp_filt_bw_t       temp_filt_bw;             ///< Sets the bandwidth of the temperature signal DLPF.

} i2c_io_icm42670_mode_extended_cfg_t;


// private functions
fsp_err_t i2c_io_icm42670_write (uint8_t * const p_src, uint8_t const bytes);
fsp_err_t i2c_io_icm42670_read (rm_comms_write_read_params_t write_read_params);
fsp_err_t i2c_io_icm42670_int_cfg_register_write(void);
fsp_err_t i2c_io_icm42670_deviceStatusGet ( void );
void i2c_io_icm42670_device_status_check (i2c_api_icm42670_device_status_t * const p_status);


// function definitions
fsp_err_t i2c_io_icm42670_software_reset (void);
fsp_err_t i2c_io_icm42670_clk_sel (void);
fsp_err_t i2c_io_icm42670_mclk_rdy (void);
fsp_err_t i2c_io_icm42670_all_interrupt_bits_clear (void);
fsp_err_t i2c_io_icm42670_who_am_I (void);

// enhanced function definition
fsp_err_t i2c_iodrm_icm42670_data_ready_open(void);
fsp_err_t i2c_iodrm_icm42670_data_ready_accel_read(i2c_api_icm42670_raw_data_t * const p_raw_data);
fsp_err_t i2c_iodrm_icm42670_data_ready_accel_data_calculate ( i2c_api_icm42670_raw_data_t * const   p_raw_data, i2c_api_icm42670_accel_data_t * const p_icm42670_data);
fsp_err_t i2c_iodrm_icm42670_data_ready_gyro_data_calculate ( i2c_api_icm42670_raw_data_t * const  p_raw_data, i2c_api_icm42670_gyro_data_t * const p_icm42670_data);
fsp_err_t i2c_iodrm_icm42670_data_ready_temp_data_calculate (i2c_api_icm42670_raw_data_t * const p_raw_data,
                                                             i2c_api_icm42670_temp_data_t * const p_icm42670_data, int16_t offset);
fsp_err_t i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_set (i2c_api_icm42670_device_interrupt_cfg_t const interrupt_cfg);
void      i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_get (i2c_api_icm42670_device_interrupt_cfg_t * p_interrupt_cfg);


// enhanced function definition (private functions)
fsp_err_t i2c_iodrm_icm42670_accel_configuration(void);
fsp_err_t i2c_iodrm_icm42670_gyro_configuration(void);
fsp_err_t i2c_iodrm_icm42670_data_ready_close (void);
fsp_err_t i2c_iodrm_icm42670_data_ready_measurement_start (void);
fsp_err_t i2c_iodrm_icm42670_data_ready_measurement_stop (void);
fsp_err_t i2c_iodrm_icm42670_data_ready_device_status_get (void);
fsp_err_t i2c_iodrm_icm42670_pwr_mgmt_configuration (void);
fsp_err_t i2c_iodrm_icm42670_data_ready_fifo_info_get (i2c_api_icm42670_fifo_info_t * const p_fifo_info);
fsp_err_t i2c_iodrm_icm42670_data_ready_temp_read (i2c_api_icm42670_raw_data_t * const p_raw_data);
fsp_err_t i2c_iodrm_icm42670_data_ready_gyro_read ( i2c_api_icm42670_raw_data_t * const p_raw_data);

void i2c_iodrm_icm42670_accel_setMode (rm_icm42670_accel_sensor_mode_t  accel_sensor_mode, int16_t  accel_fs, uint16_t accel_odr );


#endif /* I2C_DEVICE_ICM42670_I2C_IO_ICM42670_H_ */
