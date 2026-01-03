
/***********************************************************************************************************************
 * File Name    : I2C_common.c
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


#include "I2C_common.h"

/* Init the common middle ware for I2C bus 1 */
fsp_err_t i2c_bus1_comon_init(void)
{
    fsp_err_t err;
    i2c_master_instance_t *p_driver_instance = (i2c_master_instance_t*) g_comms_i2c_bus1_extended_cfg.p_driver_instance;

    /* Open I2C driver, this must be done before calling any COMMS API */
    err = p_driver_instance->p_api->open (p_driver_instance->p_ctrl, p_driver_instance->p_cfg);
    if (FSP_SUCCESS != err)
        return err;

    #if BSP_CFG_RTOS
      /* Create a semaphore for blocking if a semaphore is not NULL */
      if (NULL != g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore)
      {
        #if BSP_CFG_RTOS == 1 // AzureOS
        tx_semaphore_create(g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_handle,
                            g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_name,
                            (ULONG) 0);
        #elif BSP_CFG_RTOS == 2 // FreeRTOS
        *(g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_handle)
            = xSemaphoreCreateCountingStatic((UBaseType_t) 1, (UBaseType_t) 0, g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_memory);
        #endif
      }

      /* Create a recursive mutex for bus lock if a recursive mutex is not NULL */
      if (NULL != g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex)
      {
        #if BSP_CFG_RTOS == 1 // AzureOS
          tx_mutex_create(g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_handle,
                          g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_name,
                          TX_INHERIT);
        #elif BSP_CFG_RTOS == 2 // FreeRTOS
          *(g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_handle)
            = xSemaphoreCreateRecursiveMutexStatic(g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_memory);
        #endif
       }
    #endif
    return (err);
}

/* DeInit the common middle ware for I2C bus 1 */
fsp_err_t i2c_bus1_comon_deinit(void)
{
    i2c_master_instance_t *p_driver_instance = (i2c_master_instance_t*) g_comms_i2c_bus1_extended_cfg.p_driver_instance;

    /* Close I2C driver */
    fsp_err_t err = p_driver_instance->p_api->close (p_driver_instance->p_ctrl);

    #if BSP_CFG_RTOS
        /* Delete a semaphore for blocking if a semaphore is not NULL */
        if (NULL != g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore)
        {
        #if BSP_CFG_RTOS == 1 // AzureOS
            tx_semaphore_delete(g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_handle);
        #elif BSP_CFG_RTOS == 2 // FreeRTOS
            vSemaphoreDelete(*(g_comms_i2c_bus1_extended_cfg.p_blocking_semaphore->p_semaphore_handle));
        #endif
        }

        /* Delete a recursive mutex for bus lock if a recursive mutex is not NULL */
        if (NULL != g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex)
        {
        #if BSP_CFG_RTOS == 1 // AzureOS
            tx_mutex_delete(g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_handle);
        #elif BSP_CFG_RTOS == 2 // FreeRTOS
            vSemaphoreDelete(*(g_comms_i2c_bus1_extended_cfg.p_bus_recursive_mutex->p_mutex_handle));
        #endif
        }
    #endif

    return(err);
}
