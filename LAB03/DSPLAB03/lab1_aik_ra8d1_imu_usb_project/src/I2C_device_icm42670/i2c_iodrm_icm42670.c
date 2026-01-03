
/***********************************************************************************************************************
 * File Name    : i2c_iodrm_icm42670.c
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


/* Definitions of Mask */
 #define RM_ICM42670_MASK_PERSIST                 (0x0F)
 #define RM_ICM42670_MASK_DATA                    (0x0F)
 #define RM_ICM42670_MASK_ACCEL_THRESHOLD         (0x000FFFFF)
 #define RM_ICM42670_MASK_LED_CURRENT             (0x03FF)
 #define RM_ICM42670_MASK_8BITS                   (0xFF)
 #define RM_ICM42670_MASK_HYSTERESIS              (0x7F)

/* Definitions of Calculation */
 #define RM_ICM42670_MAX_NUM_ACCEL_SOURCE         (5)
 #define RM_ICM42670_SENSOR_G                     (9.8f)
 #define RM_ICM42670_SENSOR_PI                    (3.14f)

#include "hal_data.h"
#include "i2c_io_icm42670.h"
#include "i2c_comm_icm42670_interface.h"
#include "rm_icm42670_reg.h"

i2c_io_icm42670_mode_extended_cfg_t i2c_io_drm_icm42670_cfg =
{
  .int_type = RM_ICM42670_OPERATION_INTERRUPT_TYPE_INT1,
  .mode_irq = RM_ICM42670_OPERATION_MODE_6AXIS,
  .interrupt_source = RM_ICM42670_INTERRUPT_SOURCE_DRDY_INT1_EN,
  .interrupt_config = RM_ICM42670_INTERRUPT_CONFIG_DEFAULT_INT1,
  .pwr_rc_idle = RM_ICM42670_PWR_RC_ON,
  .clksel = RM_ICM42670_SELECT_RC_OSC,

  .accel_sensor_mode = RM_ICM42670_ACCEL_SENSOR_MODE_LP,
  .accel_fs = 8,
  .accel_odr = 25,
  //.accel_sensor_mode = RM_ICM42670_ACCEL_SENSOR_MODE_LN,//LP,
  //.accel_fs = 2, //8
  //.accel_odr = 1600,//25,
  .accel_lp_clk_sel = RM_ICM42670_ACCEL_CLK_SEL_WAKEUP_OSC,
  .accel_ui_filt_bw = RM_ICM42670_ACCEL_UI_FILT_BYPASSED,
  .accel_ui_avg = RM_ICM42670_ACCEL_UI_AVG_2x,

  .gyro_sensor_mode = RM_ICM42670_GYRO_SENSOR_MODE_OFF ,
  .gyro_fs = 1000,
  .gyro_odr = 25,
  .gyro_ui_filt_bw = RM_ICM42670_GYRO_UI_FILT_BYPASSED,
  .temp_filt_bw = RM_ICM42670_TEMP_DLPF_BYPASSED,
};

// control variable definitions
extern i2c_api_icm42670_device_ctrl_t i2c_api_icm42670_dCtrl ;
i2c_io_icm42670_mode_extended_cfg_t *i2c_io_drm_icm42670_cfg_p = &i2c_io_drm_icm42670_cfg ;

/***********************************************************************************************************************
 * Functions
 **********************************************************************************************************************/

/*******************************************************************************************************************//**
 * @brief Configures the ICM42670 Gyroscope mode.
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_open(void)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Accel configuration */
    err = i2c_iodrm_icm42670_accel_configuration();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Gyroscope configuration */
    err = i2c_iodrm_icm42670_gyro_configuration();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    //err = i2c_iodrm_icm42670_accel_gyro_device_interrupt_cfg_set(p_ctrl, p_cfg);
    //FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}



/*******************************************************************************************************************//**
 * @brief Configure fs and odr of the ICM42670 Accelerometer mode.
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_accel_configuration (void)
{
    fsp_err_t err = FSP_SUCCESS;
    uint8_t accel_cfg_tmp;

    #if RM_ICM42670_CFG_PARAM_CHECKING_ENABLE
    {
        bool err_res = !((i2c_io_drm_icm42670_cfg_p->accel_fs > 16) || (i2c_io_drm_icm42670_cfg_p->accel_fs < -16));
        FSP_ERROR_RETURN(err_res, FSP_ERR_INVALID_MODE);
    }
    #endif

    if ((i2c_io_drm_icm42670_cfg_p->accel_fs > 8) || (i2c_io_drm_icm42670_cfg_p->accel_fs < -8))
    {
        accel_cfg_tmp = RM_ICM42670_ACCEL_FS_16G << 5;
        i2c_api_icm42670_dCtrl.accel_sensitivity_shift = RM_ICM42670_ACCEL_SENSITIVITY_SCALE_FACTOR_0;
    }
    else if ((i2c_io_drm_icm42670_cfg_p->accel_fs > 4) || (i2c_io_drm_icm42670_cfg_p->accel_fs < -4))
    {
        accel_cfg_tmp = RM_ICM42670_ACCEL_FS_8G << 5;
        i2c_api_icm42670_dCtrl.accel_sensitivity_shift = RM_ICM42670_ACCEL_SENSITIVITY_SCALE_FACTOR_1;
    }
    else if ((i2c_io_drm_icm42670_cfg_p->accel_fs > 2) || (i2c_io_drm_icm42670_cfg_p->accel_fs < -2))
    {
        accel_cfg_tmp = RM_ICM42670_ACCEL_FS_4G << 5;
        i2c_api_icm42670_dCtrl.accel_sensitivity_shift = RM_ICM42670_ACCEL_SENSITIVITY_SCALE_FACTOR_2;
    }
    else
    {
        accel_cfg_tmp = RM_ICM42670_ACCEL_FS_2G << 5;
        i2c_api_icm42670_dCtrl.accel_sensitivity_shift = RM_ICM42670_ACCEL_SENSITIVITY_SCALE_FACTOR_3;
    }


    if (RM_ICM42670_ACCEL_SENSOR_MODE_LN == i2c_io_drm_icm42670_cfg_p->accel_sensor_mode)
    {

        if (i2c_io_drm_icm42670_cfg_p->accel_odr > 800)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_1600Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 400)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_800Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 200)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_400Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 100)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_200Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 50)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_100Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 25)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_50Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 12)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_25Hz;
        }
        else
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_12Hz;
        }
    }
    else if (RM_ICM42670_ACCEL_SENSOR_MODE_LP == i2c_io_drm_icm42670_cfg_p->accel_sensor_mode)
    {

        if (i2c_io_drm_icm42670_cfg_p->accel_odr > 200)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_400Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 100)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_200Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 50)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_100Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 25)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_50Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 12)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_25Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 6)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_12Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 3)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_6Hz;
        }
        else if (i2c_io_drm_icm42670_cfg_p->accel_odr > 2)
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_3Hz;
        }
        else
        {
            accel_cfg_tmp |= RM_ICM42670_ACCEL_ODR_1Hz;
        }
    }
    /* Set accel fs&odr */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_ACCEL_CONFIG0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = accel_cfg_tmp;

    err = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}



/*******************************************************************************************************************//**
 * @brief Configure fs and odr of the ICM42670 Gyroscope mode.
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_gyro_configuration (void)
{
    fsp_err_t err = FSP_SUCCESS;
    uint8_t gyro_cfg_tmp;

    #if RM_ICM42670_CFG_PARAM_CHECKING_ENABLE
    {
        bool err_res = !((i2c_io_drm_icm42670_cfg_p->gyro_fs > 2000) || (i2c_io_drm_icm42670_cfg_p->gyro_fs < -2000));
        FSP_ERROR_RETURN(err_res, FSP_ERR_INVALID_MODE);
    }
    #endif
    if ((i2c_io_drm_icm42670_cfg_p->gyro_fs > 1000) || (i2c_io_drm_icm42670_cfg_p->gyro_fs < -1000))
    {
        gyro_cfg_tmp = RM_ICM42670_GYRO_FS_16G << 5;
        i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 = RM_ICM42670_GYRO_SENSITIVITY_SCALE_FACTOR_0;
    }
    else if ((i2c_io_drm_icm42670_cfg_p->gyro_fs > 500) || (i2c_io_drm_icm42670_cfg_p->gyro_fs < -500))
    {
        gyro_cfg_tmp = RM_ICM42670_GYRO_FS_8G << 5;
        i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 = RM_ICM42670_GYRO_SENSITIVITY_SCALE_FACTOR_1;
    }
    else if ((i2c_io_drm_icm42670_cfg_p->gyro_fs > 250) || (i2c_io_drm_icm42670_cfg_p->gyro_fs < -250))
    {
        gyro_cfg_tmp = RM_ICM42670_GYRO_FS_4G << 5;
        i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 = RM_ICM42670_GYRO_SENSITIVITY_SCALE_FACTOR_2;
    }
    else
    {
        gyro_cfg_tmp = RM_ICM42670_GYRO_FS_2G << 5;
        i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 = RM_ICM42670_GYRO_SENSITIVITY_SCALE_FACTOR_3;
    }

    #if RM_ICM42670_CFG_PARAM_CHECKING_ENABLE
    {
        bool err_res = !((i2c_io_drm_icm42670_cfg_p->gyro_odr > 1600) || (i2c_io_drm_icm42670_cfg_p->gyro_odr < 12));
        FSP_ERROR_RETURN(err_res, FSP_ERR_INVALID_MODE);
    }
    #endif

    if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 800)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_1600Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 400)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_800Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 200)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_400Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 100)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_200Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 50)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_100Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 25)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_50Hz;
    }
    else if (i2c_io_drm_icm42670_cfg_p->gyro_odr > 13)
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_25Hz;
    }
    else
    {
        gyro_cfg_tmp |= RM_ICM42670_GYRO_ODR_12Hz;
    }

    /* Set gyro fs&odr */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_GYRO_CONFIG0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = gyro_cfg_tmp;
    err = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Unsupported API.
 *
 * @retval FSP_ERR_UNSUPPORTED                    Operation mode is not supported.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_close (void)
{
    return FSP_ERR_UNSUPPORTED;
}

/*******************************************************************************************************************//**
 * @brief  Start periodic measurements in both Accel mode and Gyroscope mode
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_measurement_start (void)
{
    fsp_err_t err = FSP_SUCCESS;

    uint8_t pwr_cfg_tmp;

    /* PWR_MGMT configuration */
    pwr_cfg_tmp = (RM_ICM42670_ACCEL_SENSOR_MODE_LN | (RM_ICM42670_GYRO_SENSOR_MODE_LN<<2) |
                  (RM_ICM42670_PWR_RC_ON<<4) | (RM_ICM42670_ACCEL_CLK_SEL_WAKEUP_OSC<<7));

    /* Set pwr mgmt */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_PWR_MGMT0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = pwr_cfg_tmp;
    err            = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Stop a periodic measurement
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_measurement_stop (void)
{
    fsp_err_t err = FSP_SUCCESS;

    uint8_t pwr_cfg_tmp;

    /* PWR_MGMT configuration */
    pwr_cfg_tmp = (RM_ICM42670_ACCEL_SENSOR_MODE_OFF | (RM_ICM42670_GYRO_SENSOR_MODE_STB<<2) |
                  (RM_ICM42670_PWR_RC_ON<<4) | (RM_ICM42670_ACCEL_CLK_SEL_WAKEUP_OSC<<7));

    /* Set power management */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_PWR_MGMT0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = pwr_cfg_tmp;
    err            = i2c_io_icm42670_write( &i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Reads accel data from ICM42670 device. If device interrupt is enabled, interrupt bits are cleared after data read.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_accel_read (i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;
    uint8_t bytes = RM_ICM42670_ACCEL_DATA_SIZE;
    rm_comms_write_read_params_t write_read_params;

    if (RM_ICM42670_OPERATION_MODE_6AXIS == i2c_io_drm_icm42670_cfg_p->mode_irq)
    {
        /* Clear interrupt bits after data read */
        i2c_api_icm42670_dCtrl.interrupt_bits_clear = true;
    }

    /* Read accel data. */
    i2c_api_icm42670_dCtrl.register_address     = RM_ICM42670_REG_ACCEL_DATA_X1;
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = (uint8_t *) p_raw_data;
    write_read_params.dest_bytes = bytes;
    err = i2c_io_icm42670_read( write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Calculate accel data from raw data.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_accel_data_calculate ( i2c_api_icm42670_raw_data_t * const   p_raw_data,
                                                               i2c_api_icm42670_accel_data_t * const p_icm42670_data)
{
    int16_t temp_x = 0;
    int16_t temp_y = 0;
    int16_t temp_z = 0;

    /* Get Accel data */
    temp_x = (int16_t)((uint16_t)(p_raw_data->reg_data[0]<<8) + p_raw_data->reg_data[1]);
    temp_y = (int16_t)((uint16_t)(p_raw_data->reg_data[2]<<8) + p_raw_data->reg_data[3]);
    temp_z = (int16_t)((uint16_t)(p_raw_data->reg_data[4]<<8) + p_raw_data->reg_data[5]);

    /* Calculate Accel data */
    p_icm42670_data->accel_x = (float)((temp_x * RM_ICM42670_SENSOR_G)/i2c_api_icm42670_dCtrl.accel_sensitivity_shift);
    p_icm42670_data->accel_y = (float)((temp_y * RM_ICM42670_SENSOR_G)/i2c_api_icm42670_dCtrl.accel_sensitivity_shift);
    p_icm42670_data->accel_z = (float)((temp_z * RM_ICM42670_SENSOR_G)/i2c_api_icm42670_dCtrl.accel_sensitivity_shift);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Reads Gyroscope data from ICM42670 device. If device interrupt is enabled, interrupt bits are cleared after data read.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_gyro_read ( i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;
    uint8_t bytes = RM_ICM42670_GYRO_DATA_SIZE;
    rm_comms_write_read_params_t write_read_params;

    if (RM_ICM42670_OPERATION_MODE_6AXIS == i2c_io_drm_icm42670_cfg_p->mode_irq)
    {
        /* Clear interrupt bits after data read */
        i2c_api_icm42670_dCtrl.interrupt_bits_clear = true;
    }

    /* Read gyro data. */
    i2c_api_icm42670_dCtrl.register_address     = RM_ICM42670_REG_GYRO_DATA_X1;
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = (uint8_t *) p_raw_data;
    write_read_params.dest_bytes = bytes;
    err = i2c_io_icm42670_read(write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Calculate Gyroscope data from raw data.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_gyro_data_calculate ( i2c_api_icm42670_raw_data_t * const  p_raw_data,
                                                              i2c_api_icm42670_gyro_data_t * const p_icm42670_data)
{
    int16_t temp_x = 0;
    int16_t temp_y = 0;
    int16_t temp_z = 0;

    /* Get Gyroscope data */
    temp_x = (int16_t)((uint16_t)(p_raw_data->reg_data[0]<<8) + p_raw_data->reg_data[1]);
    temp_y = (int16_t)((uint16_t)(p_raw_data->reg_data[2]<<8) + p_raw_data->reg_data[3]);
    temp_z = (int16_t)((uint16_t)(p_raw_data->reg_data[4]<<8) + p_raw_data->reg_data[5]);

    /* Calculate Gyroscope data */
    p_icm42670_data->gyro_x = (float)((temp_x * RM_ICM42670_SENSOR_PI * 10) / (i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 * 180LL));
    p_icm42670_data->gyro_y = (float)((temp_y * RM_ICM42670_SENSOR_PI * 10) / (i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 * 180LL));
    p_icm42670_data->gyro_z = (float)((temp_z * RM_ICM42670_SENSOR_PI * 10) / (i2c_api_icm42670_dCtrl.gyro_sensitivity_x10 * 180LL));

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Reads Temperature data from ICM42670 device. If device interrupt is enabled, interrupt bits are cleared after data read.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_temp_read (i2c_api_icm42670_raw_data_t * const p_raw_data)
{
    fsp_err_t err = FSP_SUCCESS;

    uint8_t bytes = RM_ICM42670_TEMP_DATA_SIZE;
    rm_comms_write_read_params_t write_read_params;

    if (RM_ICM42670_OPERATION_MODE_6AXIS == i2c_io_drm_icm42670_cfg_p->mode_irq)
    {
        /* Clear interrupt bits after data read */
        i2c_api_icm42670_dCtrl.interrupt_bits_clear = true;
    }

    /* Read accel data. */
    i2c_api_icm42670_dCtrl.register_address     = RM_ICM42670_REG_TEMP_DATA1;
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = (uint8_t *) p_raw_data;
    write_read_params.dest_bytes = bytes;
    err = i2c_io_icm42670_read(write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Calculate Temperature data from raw data.
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_temp_data_calculate (i2c_api_icm42670_raw_data_t * const p_raw_data,
                                                             i2c_api_icm42670_temp_data_t * const p_icm42670_data,
                                                             int16_t offset)
{
    /* Calculate Temperature data */
    int16_t raw_data = (int16_t)((uint16_t)(p_raw_data->reg_data[0]<<8) + p_raw_data->reg_data[1]);
    p_icm42670_data->temp_data_float = (float)(raw_data+offset)/128.0f + 25.0f;
    p_icm42670_data->temp_data       = (int16_t)(raw_data+offset)/128 + 25;

    return FSP_SUCCESS;
}

/*******************************************************************************************************************//**
 * @brief  Set device interrupt configurations.
 *
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 * @retval FSP_ERR_INVALID_MODE     Invalid mode.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_set (i2c_api_icm42670_device_interrupt_cfg_t const interrupt_cfg)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Set device interrupt configurations of int1 */
    if (RM_ICM42670_OPERATION_INTERRUPT_TYPE_INT1 == interrupt_cfg.int_type)
    {
        i2c_io_drm_icm42670_cfg_p->mode_irq = RM_ICM42670_OPERATION_MODE_6AXIS;
        i2c_io_drm_icm42670_cfg_p->interrupt_source = interrupt_cfg.int_source;
        i2c_io_drm_icm42670_cfg_p->interrupt_config = interrupt_cfg.int_config & ( RM_ICM42670_INTERRUPT_CONFIG_MASK_INT1 );
    }
    /* Set device interrupt configurations of int2 */
    if (RM_ICM42670_OPERATION_INTERRUPT_TYPE_INT2 == interrupt_cfg.int_type)
    {
        i2c_io_drm_icm42670_cfg_p->mode_irq = RM_ICM42670_OPERATION_MODE_6AXIS;
        i2c_io_drm_icm42670_cfg_p->interrupt_source = interrupt_cfg.int_source;
        i2c_io_drm_icm42670_cfg_p->interrupt_config = interrupt_cfg.int_config & RM_ICM42670_INTERRUPT_CONFIG_MASK_INT2;
    }
    else
    {
        i2c_io_drm_icm42670_cfg_p->mode_irq = RM_ICM42670_OPERATION_MODE_6AXIS;
        i2c_io_drm_icm42670_cfg_p->interrupt_source = interrupt_cfg.int_source;
        i2c_io_drm_icm42670_cfg_p->interrupt_config = interrupt_cfg.int_config & RM_ICM42670_INTERRUPT_CONFIG_MASK_INT1_INT2;
    }

    err = i2c_io_icm42670_int_cfg_register_write();
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}



/*******************************************************************************************************************//**
 * @brief  get device interrupt configurations for mode settings.
 *
 **********************************************************************************************************************/
void i2c_iodrm_icm42670_data_ready_device_interrupt_cfg_get (i2c_api_icm42670_device_interrupt_cfg_t * p_interrupt_cfg)
{
    p_interrupt_cfg->int_config = i2c_io_drm_icm42670_cfg_p->interrupt_config ;
    p_interrupt_cfg->int_source = i2c_io_drm_icm42670_cfg_p->interrupt_source ;
    p_interrupt_cfg->int_type   = i2c_io_drm_icm42670_cfg_p->int_type ;
}

/*******************************************************************************************************************//**
 * @brief  Unsupported API.
 *
 * @retval FSP_ERR_UNSUPPORTED                    Operation mode is not supported.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_fifo_info_get (i2c_api_icm42670_fifo_info_t * const p_fifo_info)
{
    FSP_PARAMETER_NOT_USED(p_fifo_info);
    return FSP_ERR_UNSUPPORTED;
}

/*******************************************************************************************************************//**
 * @brief  Unsupported API.
 *
 * @retval FSP_ERR_UNSUPPORTED                    Operation mode is not supported.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_data_ready_device_status_get (void)
{
    return FSP_ERR_UNSUPPORTED;
}

#if 1
/*******************************************************************************************************************//**
 * @brief Configures the ICM42670 accel mode.
 *
 * @retval FSP_SUCCESS              ICM42670 successfully configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_iodrm_icm42670_pwr_mgmt_configuration (void)
{
    fsp_err_t err = FSP_SUCCESS;
    uint8_t pwr_cfg_tmp;

    pwr_cfg_tmp = (i2c_io_drm_icm42670_cfg_p->accel_sensor_mode | (i2c_io_drm_icm42670_cfg_p->gyro_sensor_mode<<2) |
                  (i2c_io_drm_icm42670_cfg_p->pwr_rc_idle<<4) | (i2c_io_drm_icm42670_cfg_p->accel_lp_clk_sel<<7));

    /* Set pwr mgmt */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_PWR_MGMT0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = pwr_cfg_tmp;
    err            = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}
#endif


/*******************************************************************************************************************//**
 * @brief Configures the ICM42670 accel mode seting befor open.
 **********************************************************************************************************************/
void i2c_iodrm_icm42670_accel_setMode (rm_icm42670_accel_sensor_mode_t  accel_sensor_mode, int16_t  accel_fs, uint16_t accel_odr )
{
    i2c_io_drm_icm42670_cfg_p->accel_sensor_mode = accel_sensor_mode;
    i2c_io_drm_icm42670_cfg_p->accel_fs = accel_fs;
    i2c_io_drm_icm42670_cfg_p->accel_odr = accel_odr;
}

