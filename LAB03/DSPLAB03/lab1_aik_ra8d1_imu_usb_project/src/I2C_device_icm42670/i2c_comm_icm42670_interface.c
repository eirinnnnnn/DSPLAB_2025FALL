
/***********************************************************************************************************************
 * File Name    : i2c_comm_icm42670_interface.c
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


#include "i2c_comm_icm42670_interface.h"

// interrupt variable
volatile bool g_i2c_icm42670;

/* opens device interface */
fsp_err_t i2c_comm_icm42670_open (void)
{
    g_i2c_icm42670=false;
    fsp_err_t err =  RM_COMMS_I2C_Open(&g_comms_i2c_device1_ctrl, &g_comms_i2c_device1_cfg);

    return(err);
}

/* close device interface */
fsp_err_t i2c_comm_icm42670_close (void)
{
    fsp_err_t err =  RM_COMMS_I2C_Close (&g_comms_i2c_device1_ctrl) ;
    return(err);
}


/* read device data */
fsp_err_t i2c_comm_icm42670_read (uint8_t *const p_dest, uint32_t const bytes)
{
    fsp_err_t err = RM_COMMS_I2C_Read (&g_comms_i2c_device1_ctrl, p_dest, bytes) ;
    return(err);
}


/* write device data */
fsp_err_t i2c_comm_icm42670_write (uint8_t *const p_src, uint32_t const bytes)
{
    fsp_err_t err = RM_COMMS_I2C_Write (&g_comms_i2c_device1_ctrl, p_src, bytes) ;
    return(err);
}


/* write device data */
fsp_err_t i2c_comm_icm42670_writeRead (rm_comms_write_read_params_t const write_read_params)
{
    fsp_err_t err =  RM_COMMS_I2C_WriteRead (&g_comms_i2c_device1_ctrl, write_read_params);
    return(err);
}


/* interrupt routine comms interface */
void rm_icm42670_comms_i2c_callback(rm_comms_callback_args_t * p_args)
{
    if (RM_COMMS_EVENT_OPERATION_COMPLETE == p_args->event)
    {
        g_i2c_icm42670 = true;
    }
}

