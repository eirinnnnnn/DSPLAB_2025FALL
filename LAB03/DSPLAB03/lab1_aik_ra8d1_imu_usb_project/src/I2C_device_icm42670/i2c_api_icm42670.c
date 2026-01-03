
/***********************************************************************************************************************
 * File Name    : i2c_api_icm42670.c
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


/* Definitions of Timeout */
#define RM_ICM42670_TIMEOUT                      (10)
#define RM_ICM42670_10MS                         (10)

#include "hal_data.h"
#include "I2C_device_icm42670/i2c_api_icm42670.h"
#include "I2C_device_icm42670/i2c_io_icm42670.h"
#include "i2c_comm_icm42670_interface.h"

// control variable definitions
 i2c_api_icm42670_device_ctrl_t i2c_api_icm42670_dCtrl ;
 volatile bool g_i2c_api_irq_flag = 0;

fsp_err_t i2c_api_icm42670_open ( void )
{
    fsp_err_t err = FSP_SUCCESS;

    i2c_api_icm42670_dCtrl.fifo_reset                 = false;
    i2c_api_icm42670_dCtrl.interrupt_bits_clear       = false;
    i2c_api_icm42670_dCtrl.accel_sensitivity_shift    = RM_ICM42670_ACCEL_SENSITIVITY_SCALE_FACTOR_3;
    i2c_api_icm42670_dCtrl.gyro_sensitivity_x10       = RM_ICM42670_GYRO_SENSITIVITY_SCALE_FACTOR_3;
    i2c_api_icm42670_dCtrl.who_am_i                   = 0 ;
    /* Open Communications middleware */

    err = i2c_comm_icm42670_open () ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Software reset */
    err = i2c_io_icm42670_software_reset();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Delay 10ms */
    R_BSP_SoftwareDelay(RM_ICM42670_10MS, BSP_DELAY_UNITS_MILLISECONDS);

    /* clock select */
    err = i2c_io_icm42670_clk_sel();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Delay 10ms */
    R_BSP_SoftwareDelay(RM_ICM42670_10MS, BSP_DELAY_UNITS_MILLISECONDS);

    err = i2c_io_icm42670_mclk_rdy();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Clear all interrupt bits */
    err = i2c_io_icm42670_all_interrupt_bits_clear();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Open operation mode */
    err = i2c_iodrm_icm42670_data_ready_open();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* check supported device */
    err = i2c_io_icm42670_who_am_I();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/* close device interface */
fsp_err_t i2c_api_icm42670_close ( void )
{
    fsp_err_t err = FSP_SUCCESS;

    /* stop measurement */
    err =  i2c_iodrm_icm42670_data_ready_measurement_stop();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Software reset */
    err = i2c_io_icm42670_software_reset();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    g_i2c_api_irq_flag=false;

    // last step close the interface
    err =  i2c_comm_icm42670_close () ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


unsigned char i2c_api_icm42670_get_who_am_i( void )
{
    return(i2c_api_icm42670_dCtrl.who_am_i);
}


/*******************************************************************************************************************//**
 * @brief  Start measurement.
 * Implements @ref rm_icm42670_api_t::measurementStart
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_measurementStart( void )
{
    fsp_err_t err = FSP_SUCCESS;

    /* Start measurement */
    err = i2c_iodrm_icm42670_data_ready_measurement_start () ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Get Sensor status.
 * Implements @ref rm_icm42670_api_t::measurementStart
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/

fsp_err_t i2c_api_icm42670_deviceStatusGet( i2c_api_icm42670_device_status_t * const p_status )
{
    fsp_err_t err = i2c_io_icm42670_deviceStatusGet ( );
    i2c_io_icm42670_device_status_check (p_status);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Reads Temperature data from ICM42670 device.
 * Implements @ref rm_icm42670_api_t::TempRead
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_tempRead ( i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Read PPG raw data */
    err =  i2c_iodrm_icm42670_data_ready_temp_read (p_raw_data);

    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Calculate Temperature data from raw data.
 * Implements @ref rm_icm42670_api_t::ppgDataCalculate
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_tempDataCalculate ( i2c_api_icm42670_raw_data_t * const p_raw_data,
                                               i2c_api_icm42670_temp_data_t * const p_icm42670_data,
                                               int16_t offset)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Calculate PPG data from raw data */
    err = i2c_iodrm_icm42670_data_ready_temp_data_calculate ( p_raw_data,
                                                              p_icm42670_data,
                                                              offset);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Reads Accel data from ICM42670 device.
 * If device interrupt is enabled, interrupt bits are cleared after data read.
 * Implements @ref rm_icm42670_api_t::accelRead
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_accelRead( i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Read Accel raw data */
    err =  i2c_iodrm_icm42670_data_ready_accel_read (p_raw_data);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Calculate accel data from raw data.
 * Implements @ref rm_icm42670_api_t::accelDataCalculate
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_accelDataCalculate (  i2c_api_icm42670_raw_data_t * const   p_raw_data,
                                        i2c_api_icm42670_accel_data_t * const p_icm42670_data)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Calculate Accel data from raw data */
    err = i2c_iodrm_icm42670_data_ready_accel_data_calculate ( p_raw_data, p_icm42670_data) ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Reads gyroscope data from ICM42670 device.
 * If device interrupt is enabled, interrupt bits are cleared after data read.
 * Implements @ref rm_icm42670_api_t::gyroRead
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_gyroRead (i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Read Gyro raw data */
    err = i2c_iodrm_icm42670_data_ready_gyro_read(p_raw_data);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Calculate gyroscope data from raw data.
 * Implements @ref rm_icm42670_api_t::gyroDataCalculate
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_gyroDataCalculate (i2c_api_icm42670_raw_data_t * const  p_raw_data,
                                                i2c_api_icm42670_gyro_data_t * const p_icm42670_data)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Calculate Gyro data from raw data */
    err = i2c_iodrm_icm42670_data_ready_gyro_data_calculate(p_raw_data, p_icm42670_data);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}



/*******************************************************************************************************************//**
 * @brief  Set device interrupt configurations. This function should be called after calling RM_ICM42670_MeasurementStop().
 * Implements @ref rm_icm42670_api_t::deviceInterruptCfgSet
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 **********************************************************************************************************************/
fsp_err_t i2c_api_icm42670_deviceInterruptCfgSet (i2c_api_icm42670_device_interrupt_cfg_t const interrupt_cfg)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Set PPG device interrupt configuration */
    err = i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_set (interrupt_cfg);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Get device interrupt configurations from storage pool (not device).
 * Implements @ref rm_icm42670_api_t::deviceInterruptCfgGet
 *
 **********************************************************************************************************************/
void i2c_api_icm42670_deviceInterruptCfgGet (i2c_api_icm42670_device_interrupt_cfg_t * p_interrupt_cfg)
{
    /* Set PPG device interrupt configuration */
    i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_get (p_interrupt_cfg);
}

//
// Interrupt routine for external interrupt
//

/**********************************************************************************************************************
 * user irq interrupt (external) please use thefunction name in the definition
 *********************************************************************************************************************/
void i2c_api_icm42670_irq_callback (external_irq_callback_args_t * p_args)
{
    FSP_PARAMETER_NOT_USED(p_args);
    g_i2c_api_irq_flag = 1;

}

/**********************************************************************************************************************
 * set accel operation basic configuration
 * @note asset demo uses i2c_api_icm42670_accel_setMode (RM_ICM42670_ACCEL_SENSOR_MODE_LN, 2, 1600)
 *********************************************************************************************************************/
void i2c_api_icm42670_accel_setMode (rm_icm42670_accel_sensor_mode_t  accel_sensor_mode, int16_t  accel_fs, uint16_t accel_odr )
{
    i2c_iodrm_icm42670_accel_setMode (accel_sensor_mode, accel_fs, accel_odr);
}
