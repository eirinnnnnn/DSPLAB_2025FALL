
/***********************************************************************************************************************
 * File Name    : i2c_io_icm42670.c
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


#include "hal_data.h"
#include  "i2c_io_icm42670.h"
#include  "i2c_comm_icm42670_interface.h"

extern i2c_api_icm42670_device_ctrl_t i2c_api_icm42670_dCtrl ;
extern volatile bool g_i2c_icm42670;

/*******************************************************************************************************************//**
 * @brief Write data to ICM42670 device.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          communication is timeout.
 * @retval FSP_ERR_ABORTED          communication is aborted.
 **********************************************************************************************************************/

fsp_err_t i2c_io_icm42670_write (uint8_t * const p_src, uint8_t const bytes)
{
    fsp_err_t err = FSP_SUCCESS;

    uint16_t counter = 0;

    while((true != g_i2c_icm42670) && ( counter < RM_ICM42670_TIMEOUT ) ) {
        R_BSP_SoftwareDelay(1, BSP_DELAY_UNITS_MILLISECONDS);
        counter++;
    }

    g_i2c_icm42670 = false;
    counter = 0;

    /* Write data */
    err =  i2c_comm_icm42670_write ( p_src, (uint32_t) bytes) ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Wait callback */
    while(false == g_i2c_icm42670)
    {
        R_BSP_SoftwareDelay(1, BSP_DELAY_UNITS_MILLISECONDS);
        counter++;
        FSP_ERROR_RETURN(RM_ICM42670_TIMEOUT >= counter, FSP_ERR_TIMEOUT);
    }

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief Read data from ICM42670 device.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          communication is timeout.
 * @retval FSP_ERR_ABORTED          communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_read (rm_comms_write_read_params_t write_read_params)
{
    fsp_err_t err = FSP_SUCCESS;
    uint16_t counter = 0;

    /* Clear flag */
    while((true != g_i2c_icm42670) && ( counter < RM_ICM42670_TIMEOUT ) ) {
        R_BSP_SoftwareDelay(1, BSP_DELAY_UNITS_MILLISECONDS);
        counter++;
    }
    g_i2c_icm42670 = false;
    counter = 0;

    /* WriteRead data */
    err = i2c_comm_icm42670_writeRead (write_read_params) ;
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    /* Wait callback */
    while(false == g_i2c_icm42670)
    {
        R_BSP_SoftwareDelay(1, BSP_DELAY_UNITS_MILLISECONDS);
        counter++;
        FSP_ERROR_RETURN(RM_ICM42670_TIMEOUT >= counter, FSP_ERR_TIMEOUT);
    }

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief Software reset.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_software_reset (void)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Set the data */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_SIGNAL_PATH_RESET;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = RM_ICM42670_COMMAND_SOFTWARE_RESET;

    /* Software reset */
    err = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief clock select:always use internal RC oscillator.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_clk_sel (void)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Set the data */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_INTF_CONFIG1;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = RM_ICM42670_SELECT_RC_OSC;

    /* write clk_sel to register */
    err = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief clock select:always use internal RC oscillator.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_mclk_rdy (void)
{
    fsp_err_t err = FSP_SUCCESS;
    rm_comms_write_read_params_t write_read_params;
    uint8_t counter = 0;
    i2c_api_icm42670_dCtrl.ioBbuffer[0]=0;
    while ((i2c_api_icm42670_dCtrl.ioBbuffer[0] &0x01) != 0x01)
    {
        R_BSP_SoftwareDelay(1, BSP_DELAY_UNITS_MILLISECONDS);
        counter++;
        //FSP_ERROR_RETURN(RM_ICM42670_TIMEOUT >= counter, FSP_ERR_TIMEOUT);
        FSP_ERROR_RETURN(RM_ICM42670_TIMEOUT >= counter, FSP_SUCCESS);
        /* read mclk value */
        i2c_api_icm42670_dCtrl.register_address = RM_ICM42670_REG_MCLK_RDY;
        write_read_params.p_src                 = &i2c_api_icm42670_dCtrl.register_address;
        write_read_params.src_bytes             = 1;
        write_read_params.p_dest                = &i2c_api_icm42670_dCtrl.ioBbuffer[0];
        write_read_params.dest_bytes            = 1;
        err = i2c_io_icm42670_read(write_read_params);
        FSP_ERROR_RETURN(FSP_SUCCESS == err, err);
        //err = i2c_io_icm42670_read(write_read_params);
    }
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief Clear all interrupt bits.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_all_interrupt_bits_clear (void)
{
    fsp_err_t err = FSP_SUCCESS;
    rm_comms_write_read_params_t write_read_params;

    /* Clear all interrupt bits */
    i2c_api_icm42670_dCtrl.register_address = RM_ICM42670_REG_ADDR_INT_STATUS;
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = &i2c_api_icm42670_dCtrl.ioBbuffer[0];
    write_read_params.dest_bytes = 4;
    err = i2c_io_icm42670_read(write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief clock select:always use internal RC oscillator.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_who_am_I (void)
{
    fsp_err_t err = FSP_SUCCESS;
    rm_comms_write_read_params_t write_read_params;

    /* Clear all interrupt bits */
    i2c_api_icm42670_dCtrl.register_address     = RM_ICM42670_REG_WHO_AM_I;
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = &i2c_api_icm42670_dCtrl.ioBbuffer[0];
    write_read_params.dest_bytes = 1;
    err = i2c_io_icm42670_read(write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    i2c_api_icm42670_dCtrl.who_am_i = i2c_api_icm42670_dCtrl.ioBbuffer[0];

    if ((i2c_api_icm42670_dCtrl.ioBbuffer[0] != RM_ICM42670_WHO_AM_I_ICM42671) &&
        (i2c_api_icm42670_dCtrl.ioBbuffer[0] != RM_ICM42670_WHO_AM_I_ICM42670))
    {
        err = FSP_ERR_INVALID_DATA;
    }
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}

extern i2c_io_icm42670_mode_extended_cfg_t *i2c_io_drm_icm42670_cfg_p ;

/*******************************************************************************************************************//**
 * @brief Write data to the INT_CFG and INT_PST registers.
 *
 * @retval FSP_SUCCESS              Successfully started.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_int_cfg_register_write(void)
{
    fsp_err_t err = FSP_SUCCESS;

    /* Set the interrupt source data */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_INT_SOURCE0;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = (uint8_t)(i2c_io_drm_icm42670_cfg_p->interrupt_source & 0x000000FF);
    i2c_api_icm42670_dCtrl.ioBbuffer[2] = (uint8_t)(i2c_io_drm_icm42670_cfg_p->interrupt_source & 0x0000FF00);
    i2c_api_icm42670_dCtrl.ioBbuffer[3] = (uint8_t)(i2c_io_drm_icm42670_cfg_p->interrupt_source & 0x00FF0000);
    i2c_api_icm42670_dCtrl.ioBbuffer[4] = (uint8_t)(i2c_io_drm_icm42670_cfg_p->interrupt_source & 0xFF000000);

    /* Write the interrupt source data */
    err = i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 5);

    /* Set the interrupt config data */
    i2c_api_icm42670_dCtrl.ioBbuffer[0] = RM_ICM42670_REG_INT_CONFIG;
    i2c_api_icm42670_dCtrl.ioBbuffer[1] = i2c_io_drm_icm42670_cfg_p->interrupt_config;

    R_BSP_SoftwareDelay(50, 1);

    /* Write the interrupt config data */
    err |= i2c_io_icm42670_write(&i2c_api_icm42670_dCtrl.ioBbuffer[0], 2);

    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief  Get device status from ICM42670 device. Clear all interrupt bits.
 * Implements @ref rm_icm42670_api_t::deviceStatusGet
 *
 * @retval FSP_SUCCESS              Successfully results are read.
 * @retval FSP_ERR_ASSERTION        Null pointer passed as a parameter.
 * @retval FSP_ERR_NOT_OPEN         Module is not opened configured.
 * @retval FSP_ERR_TIMEOUT          Communication is timeout.
 * @retval FSP_ERR_ABORTED          Communication is aborted.
 **********************************************************************************************************************/
fsp_err_t i2c_io_icm42670_deviceStatusGet ( void )
{
    fsp_err_t err = FSP_SUCCESS;
    rm_comms_write_read_params_t write_read_params;

    /* Get status */
    i2c_api_icm42670_dCtrl.register_address     = RM_ICM42670_REG_ADDR_INT_STATUS; //Begin with 0x39(INT_STATUS_DRDY)
    write_read_params.p_src      = &i2c_api_icm42670_dCtrl.register_address;
    write_read_params.src_bytes  = 1;
    write_read_params.p_dest     = &i2c_api_icm42670_dCtrl.ioBbuffer[0];
    write_read_params.dest_bytes = 4;                          //0x39(INT_STATUS_DRDY)--0x3C(INT_STATUS3)
    err = i2c_io_icm42670_read(write_read_params);
    FSP_ERROR_RETURN(FSP_SUCCESS == err, err);

    return FSP_SUCCESS;
}


/*******************************************************************************************************************//**
 * @brief Check device status and set callback event.
 **********************************************************************************************************************/
void i2c_io_icm42670_device_status_check (i2c_api_icm42670_device_status_t * const p_status)
{

    /* Check if INT_STATUS_DRDY occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[0] & RM_ICM42670_MASK_DATA_RDY_STATUS))
    {
        p_status->data_ready = true;
    }
    else
    {
        p_status->data_ready = false;
    }
    /* Check if power-on-reset occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_RESET_DONE))
    {
        p_status->power_on_reset_occur = true;
    }
    else
    {
        p_status->power_on_reset_occur = false;
    }

    /* Check if Accel mode interrupt condition occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_AGC_RDY_STATUS))
    {
        p_status->agc_ready = true;
    }
    else
    {
        p_status->agc_ready = false;
    }

    /* Check if FIFO full interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_FIFO_FULL_STATUS))
    {
        p_status->fifo_afull_int_occur = true;
    }
    else
    {
        p_status->fifo_afull_int_occur = false;
    }

    /* Check if FIFO threshold interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_FIFO_THS_STATUS))
    {
        p_status->fifo_ths_int_occur = true;
    }
    else
    {
        p_status->fifo_ths_int_occur = false;
    }

    /* Check if PLL ready interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_PLL_RDY_STATUS))
    {
        p_status->pll_ready = true;
    }
    else
    {
        p_status->pll_ready = false;
    }

    /* Check if FSYNC interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_FSYNC_STATUS))
    {
        p_status->FSYNC_int_occur = true;
    }
    else
    {
        p_status->FSYNC_int_occur = false;
    }

    /* Check if selftest done interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[1] & RM_ICM42670_MASK_ST_STATUS))
    {
        p_status->self_test_done = true;
    }
    else
    {
        p_status->self_test_done = false;
    }

    /* Check if WOM_Z interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[2] & RM_ICM42670_MASK_WOM_Z_STATUS))
    {
        p_status->wom_z_occur = true;
    }
    else
    {
        p_status->wom_z_occur = false;
    }

    /* Check if WOM_Y interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[2] & RM_ICM42670_MASK_WOM_Y_STATUS))
    {
        p_status->wom_y_occur = true;
    }
    else
    {
        p_status->wom_y_occur = false;
    }

    /* Check if WOM_X interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[2] & RM_ICM42670_MASK_WOM_X_STATUS))
    {
        p_status->wom_x_occur = true;
    }
    else
    {
        p_status->wom_x_occur = false;
    }

    /* Check if SMD interrupt occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[2] & RM_ICM42670_MASK_SMD_STATUS))
    {
        p_status->SMD_occur = true;
    }
    else
    {
        p_status->SMD_occur = false;
    }

    /* Check if LowG detection */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[3] & RM_ICM42670_MASK_LOWG_DET_STATUS))
    {
        p_status->lowG_occur = true;
    }
    else
    {
        p_status->lowG_occur = false;
    }

    /* Check if FF detection */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[3] & RM_ICM42670_MASK_FF_DET_STATUS))
    {
        p_status->freefall_occur = true;
    }
    else
    {
        p_status->freefall_occur = false;
    }

    /* Check if tilt detection */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[3] & RM_ICM42670_MASK_TILT_DET_STATUS))
    {
        p_status->tilt_detection = true;
    }
    else
    {
        p_status->tilt_detection = false;
    }

    /* Check if step count overflow occurs */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[3] & RM_ICM42670_MASK_STEP_CNT_OVF_STATUS))
    {
        p_status->step_count_overflow_occur = true;
    }
    else
    {
        p_status->step_count_overflow_occur = false;
    }

    /* Check if step detection */
    if (0x00 != (i2c_api_icm42670_dCtrl.ioBbuffer[3] & RM_ICM42670_MASK_STEP_DET_STATUS))
    {
        p_status->step_detection = true;
    }
    else
    {
        p_status->step_detection = false;
    }

}


