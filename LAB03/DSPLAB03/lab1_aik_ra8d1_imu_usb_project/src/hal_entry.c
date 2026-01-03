/***********************************************************************************************************************
 * File Name    : hal_entry.c
 * Description  : Entry function.
 **********************************************************************************************************************/
/***********************************************************************************************************************
* Copyright (c) 2020 - 2024 Renesas Electronics Corporation and/or its affiliates
*
* SPDX-License-Identifier: BSD-3-Clause
***********************************************************************************************************************/

#include <stdio.h>
#include <string.h>
#include "hal_entry.h"
#include "common_init.h"
#include "SEGGER_RTT/SEGGER_RTT.h"
#include "I2C_device_icm42670/i2c_api_icm42670.h"
#include "I2C_common/I2C_common.h"
#include "hal_data.h"
/* Function declaration */
void R_BSP_WarmStart(bsp_warm_start_event_t event);
/* Global variables */
extern uint8_t g_apl_device[];
extern uint8_t g_apl_configuration[];
extern uint8_t g_apl_hs_configuration[];
extern uint8_t g_apl_qualifier_descriptor[];
extern uint8_t *g_apl_string_table[];
extern  volatile bool g_i2c_api_irq_flag;


const usb_descriptor_t usb_descriptor =
{
 g_apl_device,                   /* Pointer to the device descriptor */
 g_apl_configuration,            /* Pointer to the configuration descriptor for Full-speed */
 g_apl_hs_configuration,         /* Pointer to the configuration descriptor for Hi-speed */
 g_apl_qualifier_descriptor,     /* Pointer to the qualifier descriptor */
 g_apl_string_table,             /* Pointer to the string descriptor table */
 NUM_STRING_DESCRIPTOR
};

usb_status_t            usb_event;

static bool  b_usb_attach = false;

/* Private functions */
static fsp_err_t check_for_write_complete(void);


fsp_err_t g_err = FSP_SUCCESS;
uint8_t g_buf[READ_BUF_SIZE]            = {0};
int16_t accel_data[5] = {0};
volatile bool bStartReading = 0;

static i2c_api_icm42670_raw_data_t   raw_data;
//static i2c_api_icm42670_accel_data_t icm42670_accel_data;
//static i2c_api_icm42670_gyro_data_t icm42670_gyro_data;

bool gb20ms_cycle = 0;


static void rst_high(void);
static void rst_low(void);
static void cts_high(void);
static void cts_low(void);

fsp_err_t err = FSP_SUCCESS;

uint8_t rx_buf[20] = {0};
uint8_t tx_buf[20] = {0};
uint8_t rx_cnt = 0;
uint8_t tx_cnt = 0;
volatile bool uart_rx_done = 0;
volatile bool uart_tx_done = 0;
//volatile bool gbCycle100ms = 0;
uint16_t sensor_data_counter=0;
/*******************************************************************************************************************//**
 * The RA Configuration tool generates main() and uses it to generate threads if an RTOS is used.  This function is
 * called by main() when no RTOS is used.
 **********************************************************************************************************************/
void hal_entry(void)
{
    //fsp_err_t err                           = FSP_SUCCESS;
    usb_event_info_t    event_info          = {0};

    static usb_pcdc_linecoding_t g_line_coding;

    SEGGER_RTT_printf(0,"Power ON\r\n");

    /* init the i2c comm interface */
     err = i2c_bus1_comon_init();
     if (err != FSP_SUCCESS)
     {
         SEGGER_RTT_printf(0,"I2C common interface: initialization failed.\r\n");
     }
     SEGGER_RTT_printf (0,"I2c common interface : initialized.\r\n");


     /* Open ICM42670  open I2C bus and init sensor */
     i2c_api_icm42670_accel_setMode (RM_ICM42670_ACCEL_SENSOR_MODE_LN, 2, 1600);
     err = i2c_api_icm42670_open();
     SEGGER_RTT_printf(0, "sensor ack <WhoAmI>  : 0x%2x\r\n",i2c_api_icm42670_get_who_am_i());


     if (err != FSP_SUCCESS)
     {
         SEGGER_RTT_printf (0, "I2c sensor setup     : failed.\r\n");
     }

     SEGGER_RTT_printf (0, "I2c ICM42670 setup   : done.\r\n");
     /* end */
     {
         i2c_api_icm42670_device_interrupt_cfg_t interrupt_cfg ;
         i2c_api_icm42670_deviceInterruptCfgGet (&interrupt_cfg); //get the recommended settings ;
         //interrupt_cfg.int_config |= 0x01 ; // use active high interrupt
         err =  i2c_api_icm42670_deviceInterruptCfgSet (interrupt_cfg);

         if (err != FSP_SUCCESS)
         {
             SEGGER_RTT_printf (0, "ICM42670 interrupts  : initialization failed.\r\n");
         }
         SEGGER_RTT_printf (0, "ICM42670 interrupts  : initialized.\r\n");
     }

    /* Start measurement in data ready mode */
     err = i2c_api_icm42670_measurementStart();
     if (err != FSP_SUCCESS)
     {
         SEGGER_RTT_printf (0, "ICM42670 measurement : Failed to start.\r\n");
     }
     SEGGER_RTT_printf (0, "ICM42670 measurement : started\r\n");


    /* Open external IRQ */
    err = R_ICU_ExternalIrqOpen(&g_external_irq11_pmod1_ctrl, &g_external_irq11_pmod1_cfg);
    if (err != FSP_SUCCESS)
    {
        SEGGER_RTT_printf(0, "ICM42670 interrupt   : Failed to open.\r\n");
    }
    SEGGER_RTT_printf(0, "ICM42670 interrupt   : opened.\r\n");

    err = R_ICU_ExternalIrqEnable (&g_external_irq11_pmod1_ctrl);
    if (err != FSP_SUCCESS)
    {
        SEGGER_RTT_printf(0, "ICM42670 interrupt   : Failed to enable.\r\n");
    }
    SEGGER_RTT_printf (0,"ICM42670 interrupt   : enabled\r\n");


    /* Open USB instance */
    err = R_USB_Open (&g_basic0_ctrl, &g_basic0_cfg);
    /* Handle error */
    if (FSP_SUCCESS != err)
    {
        /* Turn ON RED LED to indicate fatal error */
        TURN_RED_ON
        APP_ERR_TRAP(err);
    }

    err = R_AGT_Open(&g_timer0_ctrl, &g_timer0_cfg);
    err = R_AGT_Start(&g_timer0_ctrl);

    /* ------------------ UART (Bluetooth) Init & Reset sequence ------------------ */
    /* Open UART for Bluetooth (g_uart3 from hal_data) */
    err = R_SCI_B_UART_Open(&g_uart3_ctrl, &g_uart3_cfg);
    if (err != FSP_SUCCESS)
    {
        SEGGER_RTT_printf(0, "UART open failed: 0x%X\r\n", err);
    }

    /* Start a small timer used by the example (timer1) for 100ms cycle if configured in your project */
    if (FSP_SUCCESS == R_AGT_Open(&g_timer0_ctrl, &g_timer0_cfg))
    {
        R_AGT_Start(&g_timer0_ctrl);
    }

    /* Prepare to receive on UART (start RX) */
    err = R_SCI_B_UART_Read(&g_uart3_ctrl, rx_buf, 2U);
    if (err != FSP_SUCCESS)
    {
        SEGGER_RTT_printf(0, "UART Read start failed: 0x%X\r\n", err);
    }

    /* Reset Bluetooth module (DA14531MOD) */
    rst_low();
    /* delay is achieved by waiting some timer cycles; use gbCycle100ms flag once timer1 fires */
    if (gb20ms_cycle) gb20ms_cycle = 0;
    /* Give some time — user_timer_cb sets gbCycle100ms periodically */
    /* Busy-wait a few cycles if timer isn't enabled (safe fallback) */
    {
        int wait_cnt = 0;
        while ((0 == gb20ms_cycle) && (wait_cnt++ < 20000))
        {
            /* short busy loop; in real code you might use a blocking delay or proper OS delay */
        }
        gb20ms_cycle = 0; /* clear */
    }
    rst_high();

    while (true)
    {
        /* Obtain USB related events */
        err = R_USB_EventGet (&event_info, &usb_event);

        /* Handle error */
        if (FSP_SUCCESS != err)
        {
            /* Turn ON RED LED to indicate fatal error */
            TURN_RED_ON
            APP_ERR_TRAP(err);
        }

        // IMU
        if(gb20ms_cycle)
        {
            gb20ms_cycle = 0; // 重置 timer 旗標
            if(g_i2c_api_irq_flag && bStartReading)
            {
    //            g_i2c_api_irq_flag = 0;
    //
    //            /* Read Accel data */
    //            err = i2c_api_icm42670_accelRead (&raw_data);
    //
    //            accel_data[0] = 0x0fff; //Prefix
    //            accel_data[1] = (int16_t)((int16_t)(raw_data.reg_data[0]<<8) + raw_data.reg_data[1]);//x
    //            accel_data[2] = (int16_t)((int16_t)(raw_data.reg_data[2]<<8) + raw_data.reg_data[3]);//y
    //            accel_data[3] = (int16_t)((int16_t)(raw_data.reg_data[4]<<8) + raw_data.reg_data[5]);//z
    //            accel_data[4] = 0x0fff; //Postfix
    //
    //            SEGGER_RTT_printf (0, "========> [%d],[%d],[%d]\r\n",accel_data[1], accel_data[2], accel_data[3]);
    //
    //            err = R_USB_Write (&g_basic0_ctrl, (uint8_t*)accel_data, sizeof(accel_data), USB_CLASS_PCDC);
    //            check_for_write_complete();
                   g_i2c_api_irq_flag = 0;

                   fsp_err_t err;
                   i2c_api_icm42670_raw_data_t raw_data_accel;
                   i2c_api_icm42670_raw_data_t raw_data_gyro;

                   int16_t sensor_data[10];  // Prefix + AccX/Y/Z + GyroX/Y/Z + Postfix

                   /* Read Accel data */
                   err = i2c_api_icm42670_accelRead(&raw_data_accel);
                   sensor_data[0] = 0x0FFF;
                   sensor_data_counter++;
                   sensor_data[1] = (int16_t) sensor_data_counter;
                   sensor_data[2] = (int16_t)((raw_data_accel.reg_data[0] << 8) | raw_data_accel.reg_data[1]);
                   sensor_data[3] = (int16_t)((raw_data_accel.reg_data[2] << 8) | raw_data_accel.reg_data[3]);
                   sensor_data[4] = (int16_t)((raw_data_accel.reg_data[4] << 8) | raw_data_accel.reg_data[5]);

                   /* Read gyroscope data */
                   err = i2c_api_icm42670_gyroRead(&raw_data_gyro);
                   sensor_data[5] = (int16_t)((raw_data_gyro.reg_data[0] << 8) | raw_data_gyro.reg_data[1]);
                   sensor_data[6] = (int16_t)((raw_data_gyro.reg_data[2] << 8) | raw_data_gyro.reg_data[3]);
                   sensor_data[7] = (int16_t)((raw_data_gyro.reg_data[4] << 8) | raw_data_gyro.reg_data[5]);
                   sensor_data[8] = 0;
                   sensor_data[9] = 0x0FFF;


                   SEGGER_RTT_printf(0,"ACC: [%d],[%d],[%d]  GYRO: [%d],[%d],[%d]\r\n",
                                     sensor_data[2], sensor_data[3], sensor_data[4],
                                     sensor_data[5], sensor_data[6], sensor_data[7]);


                   //err = R_USB_Write(&g_basic0_ctrl, (uint8_t*)sensor_data, sizeof(sensor_data), USB_CLASS_PCDC);
                   //check_for_write_complete();
                   /* ===== USB transmit ===== */
                   if (b_usb_attach)
                   {
                       err = R_USB_Write(&g_basic0_ctrl, (uint8_t *)sensor_data, sizeof(sensor_data), USB_CLASS_PCDC);
                       if (FSP_SUCCESS == err)
                       {
                           check_for_write_complete();
                       }
                       else
                       {
                           SEGGER_RTT_printf(0, "USB Write err: 0x%X\r\n", err);
                       }
                   }

                   /* ===== Bluetooth (UART) transmit ===== */
                   if (FSP_SUCCESS == R_SCI_B_UART_Write(&g_uart3_ctrl, (uint8_t *)sensor_data, sizeof(sensor_data)))
                   {
                       uart_tx_done = 0;
                       /* Wait with timeout for tx complete flag */
                       int wait = 0;
                       const int max_wait = 50000;
                       while ((!uart_tx_done) && (wait++ < max_wait))
                       {
                           /* busy wait; could insert WFI or low-power wait if available */
                       }
                       if (!uart_tx_done)
                       {
                           SEGGER_RTT_printf(0, "UART TX timeout\r\n");
                       }
                   }
            }
        }
        /* USB event received by R_USB_EventGet */
        switch (usb_event)
        {
            case USB_STATUS_CONFIGURED:
            {
                err = R_USB_Read (&g_basic0_ctrl, g_buf, READ_BUF_SIZE, USB_CLASS_PCDC);
                /* Handle error */
                if (FSP_SUCCESS != err)
                {
                    /* Turn ON RED LED to indicate fatal error */
                    TURN_RED_ON
                    APP_ERR_TRAP(err);
                }
            }break;

            case USB_STATUS_READ_COMPLETE:
            {
                if(b_usb_attach)
                {
                    err = R_USB_Read (&g_basic0_ctrl, g_buf, READ_BUF_SIZE, USB_CLASS_PCDC);
                }
                /* Handle error */
                if (FSP_SUCCESS != err)
                {
                    /* Turn ON RED LED to indicate fatal error */
                    TURN_RED_ON
                    APP_ERR_TRAP(err);
                }

#if 1
                SEGGER_RTT_printf (0, "Data receiving from Host ========> 0x%x, 0x%x, 0x%x\r\n",g_buf[0], g_buf[1], g_buf[2]);

                if(g_buf[0] == 0x5a) {
                    bStartReading = 1;
                    sensor_data_counter=0;
                }
                else if(g_buf[0] == 0x33) {
                    bStartReading = 0;
                    sensor_data_counter=0;
                }

                memset(g_buf, 0x00, sizeof(g_buf));
#else
                /* Switch case evaluation of user input */
                switch (g_buf[0])
                {
                    case 0x01:
                    {
                    }break;
                    case 0x02:
                    {
                    }break;

                    case 0x03:
                    {
                    }break;

                    default:
                    {
                    }break;
                }
#endif
            }break;

            case USB_STATUS_REQUEST : /* Receive Class Request */
            {
                /* Check for the specific CDC class request IDs */
                if (USB_PCDC_SET_LINE_CODING == (event_info.setup.request_type & USB_BREQUEST))
                {
                    err =  R_USB_PeriControlDataGet (&g_basic0_ctrl, (uint8_t *) &g_line_coding, LINE_CODING_LENGTH );
                    /* Handle error */
                    if (FSP_SUCCESS != err)
                    {
                        /* Turn ON RED LED to indicate fatal error */
                        TURN_RED_ON
                        APP_ERR_TRAP(err);
                    }
                }
                else if (USB_PCDC_GET_LINE_CODING == (event_info.setup.request_type & USB_BREQUEST))
                {
                    err =  R_USB_PeriControlDataSet (&g_basic0_ctrl, (uint8_t *) &g_line_coding, LINE_CODING_LENGTH );
                    /* Handle error */
                    if (FSP_SUCCESS != err)
                    {
                        /* Turn ON RED LED to indicate fatal error */
                        TURN_RED_ON
                        APP_ERR_TRAP(err);
                    }
                }
                else if (USB_PCDC_SET_CONTROL_LINE_STATE == (event_info.setup.request_type & USB_BREQUEST))
                {
                    err = R_USB_PeriControlStatusSet (&g_basic0_ctrl, USB_SETUP_STATUS_ACK);
                    /* Handle error */
                    if (FSP_SUCCESS != err)
                        //if (FSP_SUCCESS != g_err)
                    {
                        /* Turn ON RED LED to indicate fatal error */
                        TURN_RED_ON
                        APP_ERR_TRAP(err);
                    }
                }
                else
                {
                    /* none */
                }
            }break;

            case USB_STATUS_DETACH:
            case USB_STATUS_SUSPEND:
            {
                b_usb_attach = false;
                memset (g_buf, 0, sizeof(g_buf));
                break;
            }
            case USB_STATUS_RESUME:
            {
                b_usb_attach = true;
                break;
            }
            default:
            {
                break;
            }
        }
        if (uart_rx_done )
        {
            //err = R_SCI_B_UART_Read(&g_uart3_ctrl, rx_buf, 1U);


            uart_rx_done = 0;
            /* parse first byte similarly to USB commands */
            if (rx_buf[0] == 0x5a) {
                bStartReading = 1;
                sensor_data_counter=0;
            }
            else if (rx_buf[0] == 0x33) {
                bStartReading = 0;
                sensor_data_counter=0;
            }

            /* Start a new read to keep receiving */
            err = R_SCI_B_UART_Read(&g_uart3_ctrl, rx_buf, 1U);
            if (err != FSP_SUCCESS)
            {
                SEGGER_RTT_printf(0, "UART Read restart failed: 0x%X\r\n", err);
            }
        }
    }
}

/*******************************************************************************************************************//**
 * This function is called at various points during the startup process.  This implementation uses the event that is
 * called right before main() to set up the pins.
 *
 * @param[in]  event    Where at in the start up process the code is currently at
 **********************************************************************************************************************/
void R_BSP_WarmStart(bsp_warm_start_event_t event)
{
    if (BSP_WARM_START_POST_C == event)
    {
        /* C runtime environment and system clocks are setup. */
        /* Configure pins. */
        R_IOPORT_Open (&g_ioport_ctrl, &g_bsp_pin_cfg);
    }
}

/*****************************************************************************************************************
 *  @brief      Check for write completion
 *  @param[in]  None
 *  @retval     FSP_SUCCESS     Upon success
 *  @retval     any other error code apart from FSP_SUCCESS
 ****************************************************************************************************************/
static fsp_err_t check_for_write_complete(void)
{
    usb_status_t usb_write_event = USB_STATUS_NONE;
    int32_t timeout_count = UINT16_MAX;
    fsp_err_t err = FSP_SUCCESS;
    usb_event_info_t    event_info = {0};

    do
    {
        err = R_USB_EventGet (&event_info, &usb_write_event);
        if (FSP_SUCCESS != err)
        {
            return err;
        }

        --timeout_count;

        if (0 > timeout_count)
        {
            timeout_count = 0;
            err = (fsp_err_t)USB_STATUS_NONE;
            break;
        }
    }while(USB_STATUS_WRITE_COMPLETE != usb_write_event);

    return err;
}

/* Example callback called when timer expires. */
void user_20ms_cb (timer_callback_args_t * p_args)
{
    if (TIMER_EVENT_CYCLE_END == p_args->event)
    {
        /* Add application code to be called periodically here. */
        gb20ms_cycle = 1;

    }
}

void user_uart_cb (uart_callback_args_t * p_args)
{
    /* Handle the UART event */
    switch (p_args->event)
    {
        /* Received a character */
        case UART_EVENT_RX_CHAR:
        {
            break;
        }
        /* Receive complete */
        case UART_EVENT_RX_COMPLETE:
        {
            rx_cnt++;
            uart_rx_done = 1;
            break;
        }
        /* Transmit complete */
        case UART_EVENT_TX_COMPLETE:
        {
            tx_cnt++;
            uart_tx_done = 1;
            break;
        }
        default:
        {
        }
    }
}
static void rst_high(void)
{
    /* Enable access to the PFS registers. If using r_ioport module then register protection is automatically
    * handled. This code uses BSP IO functions to show how it is used.
    */
    R_BSP_PinAccessEnable();
    R_BSP_PinWrite(BSP_IO_PORT_04_PIN_12, BSP_IO_LEVEL_HIGH);
    /* Protect PFS registers */
    R_BSP_PinAccessDisable();
}
static void rst_low(void)
{
    /* Enable access to the PFS registers. If using r_ioport module then register protection is automatically
    * handled. This code uses BSP IO functions to show how it is used.
    */
    R_BSP_PinAccessEnable();
    R_BSP_PinWrite(BSP_IO_PORT_04_PIN_12, BSP_IO_LEVEL_LOW);
    /* Protect PFS registers */
    R_BSP_PinAccessDisable();
}
static void cts_high(void)
{
    /* Enable access to the PFS registers. If using r_ioport module then register protection is automatically
    * handled. This code uses BSP IO functions to show how it is used.
    */
    R_BSP_PinAccessEnable();
    R_BSP_PinWrite(BSP_IO_PORT_04_PIN_11, BSP_IO_LEVEL_HIGH);
    /* Protect PFS registers */
    R_BSP_PinAccessDisable();
}
static void cts_low(void)
{
    /* Enable access to the PFS registers. If using r_ioport module then register protection is automatically
    * handled. This code uses BSP IO functions to show how it is used.
    */
    R_BSP_PinAccessEnable();
    R_BSP_PinWrite(BSP_IO_PORT_04_PIN_11, BSP_IO_LEVEL_LOW);
    /* Protect PFS registers */
    R_BSP_PinAccessDisable();
}

/*******************************************************************************************************************//**
 * @} (end addtogroup hal_entry)
 **********************************************************************************************************************/

