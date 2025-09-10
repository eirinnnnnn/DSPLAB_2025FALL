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


/* Function declaration */
void R_BSP_WarmStart(bsp_warm_start_event_t event);

void delay_loop(unsigned int count);
/* Global variables */
extern uint8_t g_apl_device[];
extern uint8_t g_apl_configuration[];
extern uint8_t g_apl_hs_configuration[];
extern uint8_t g_apl_qualifier_descriptor[];
extern uint8_t *g_apl_string_table[];
uint16_t result_tx[60000][5]={0};

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

uint16_t result[5] = {0};

uint16_t result_channel_data[3] = {0};

uint16_t result_t[5] = {0};
/* Private functions */
static fsp_err_t check_for_write_complete(void);


fsp_err_t g_err = FSP_SUCCESS;
uint8_t g_buf[READ_BUF_SIZE]            = {0};
uint8_t g_tx_buf[64U] = {0};
adc_status_t adc0_status;
adc_status_t adc1_status;
uint16_t adc_cnt = 0;
uint16_t adc_cnt_reg = 0;
uint16_t adc_cnt_tx =0;
uint16_t temp_0, temp_1;
uint16_t cnt =  0;
bool gp =0;
bool gb1ms_cycle = 0;
bool reverse = 0;
bool receive_all = 0;
uint16_t channel_data[8194] = {0};
uint16_t tx_data[8194] = {0};
/*******************************************************************************************************************//**
 * The RA Configuration tool generates main() and uses it to generate threads if an RTOS is used.  This function is
 * called by main() when no RTOS is used.
 **********************************************************************************************************************/
void delay_loop(unsigned int count)
{
    int a = 0;
    for (volatile unsigned int i = 0; i < count; i++) {
        a = a+1;
    }
}
void hal_entry(void)
{
    int sample_count = 1;
    fsp_err_t err                           = FSP_SUCCESS;
    usb_event_info_t    event_info          = {0};

    static usb_pcdc_linecoding_t g_line_coding;

    SEGGER_RTT_printf(0,"Power ON\r\n");

    // ADC Initialization.
    err = R_ADC_Open(&g_adc0_ctrl, &g_adc0_cfg);
    if(FSP_SUCCESS != err)
    {
        SEGGER_RTT_printf(0,"ADC 0 : Failed to open ADC\r\n");
    }
    else
    {
        SEGGER_RTT_printf(0,"ADC 0 : Successfully opened ADC \r\n");
    }
    err = R_ADC_Open(&g_adc1_ctrl, &g_adc1_cfg);
    if(FSP_SUCCESS != err)
    {
        SEGGER_RTT_printf(0,"ADC 1 : Failed to open ADC\r\n");
    }
    else
    {
        SEGGER_RTT_printf(0,"ADC 1 : Successfully opened ADC \r\n");
    }


    err = R_ADC_ScanCfg(&g_adc0_ctrl, &g_adc0_channel_cfg);
    if(FSP_SUCCESS != err)
    {
        SEGGER_RTT_printf(0,"ADC 0 : Configuration failed.\r\n");
    }
    else
    {
        SEGGER_RTT_printf(0,"ADC 0 : Configuration successful.\r\n");
    }

    err = R_ADC_ScanCfg(&g_adc1_ctrl, &g_adc1_channel_cfg);
    if(FSP_SUCCESS != err)
    {
        SEGGER_RTT_printf(0,"ADC 1 : Configuration failed.\r\n");
    }
    else
    {
        SEGGER_RTT_printf(0,"ADC 1 : Configuration successful.\r\n");
    }

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
      R_BSP_PinAccessEnable();
      R_BSP_PinWrite(BSP_IO_PORT_01_PIN_00, BSP_IO_LEVEL_LOW);  //BSP_IO_LEVEL_LOW           /* Protect PFS registers */
      R_BSP_PinAccessDisable();

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
        // ADC
        if(adc_cnt == 8192){
            R_BSP_PinAccessEnable();
            R_BSP_PinWrite(BSP_IO_PORT_01_PIN_00, BSP_IO_LEVEL_HIGH);  //BSP_IO_LEVEL_LOW
            R_BSP_PinAccessDisable();
            delay_loop(4800);
            R_BSP_PinAccessEnable();
            R_BSP_PinWrite(BSP_IO_PORT_01_PIN_00, BSP_IO_LEVEL_LOW);  //BSP_IO_LEVEL_LOW
            /* Protect PFS registers */
            R_BSP_PinAccessDisable();
        }
        channel_data[0] = 0xdead;
        channel_data[8193] = 0xbeef;
        result_channel_data[0] = 0xdead;
        result_channel_data[2] = 0xbeef;
        if(adc_cnt > 0){
            adc_cnt_reg = adc_cnt;
//            SEGGER_RTT_printf (0, "Data sending from RA8D1 ========> adc_cnt = %d\r\n",adc_cnt);
        }
        while(adc_cnt > 0 ){
            // Scan start...
//            SEGGER_RTT_printf (0, "scan_start \r\n");
            if(gb1ms_cycle){
                err = R_ADC_ScanStart(&g_adc0_ctrl);
                err = R_ADC_ScanStart(&g_adc1_ctrl);

                adc0_status.state = ADC_STATE_SCAN_IN_PROGRESS;
                adc1_status.state = ADC_STATE_SCAN_IN_PROGRESS;
                while (ADC_STATE_SCAN_IN_PROGRESS == adc0_status.state)
                {
                   (void) R_ADC_StatusGet(&g_adc0_ctrl, &adc0_status);
                }
                while (ADC_STATE_SCAN_IN_PROGRESS == adc1_status.state)
                {
                   (void) R_ADC_StatusGet(&g_adc1_ctrl, &adc1_status);
                }

//                result[0] = 0xdead;
//                result[4] = 0xbeef;


                err = R_ADC_Read(&g_adc0_ctrl, ADC_CHANNEL_0, &result[1]);
                err = R_ADC_Read(&g_adc1_ctrl, ADC_CHANNEL_21, &result[3]);
                channel_data[sample_count] = result[1];
                tx_data[sample_count] = result[3];
                sample_count++;

//              err = R_USB_Write (&g_basic0_ctrl, (uint8_t*)result, sizeof(result), USB_CLASS_PCDC);
//              check_for_write_complete();

                adc_cnt--;
//                SEGGER_RTT_printf (0, "Data sending from RA8D1 ========> adc_cnt = %d\r\n",adc_cnt);
                //err = R_AGT_Start(&g_timer0_ctrl);
                gb1ms_cycle = 0; // 重置 timer 旗標
            }
            if(adc_cnt == 0){
                receive_all = 1;
            }
        }

        if (receive_all == 1){
            for (int i = 0;i<adc_cnt_reg;i++){
                result_channel_data[1] = channel_data[i];
                err = R_USB_Write (&g_basic0_ctrl, (uint8_t*)result_channel_data, sizeof(result_channel_data), USB_CLASS_PCDC);
//                SEGGER_RTT_printf (0, "Data sending from RA8D1 ========> i = %d, data = %d\r\n",i, result_channel_data[1]);
                check_for_write_complete();
            }
            for (int i = 0;i<adc_cnt_reg;i++){
                result_channel_data[1] = tx_data[i];
                err = R_USB_Write (&g_basic0_ctrl, (uint8_t*)result_channel_data, sizeof(result_channel_data), USB_CLASS_PCDC);
//                SEGGER_RTT_printf (0, "Data sending from RA8D1 ========> i = %d, data = %d\r\n",i, result_channel_data[1]);
                check_for_write_complete();
            }
            receive_all = 0;
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

                temp_0 = g_buf[0];
                temp_1 = g_buf[1];
                adc_cnt = temp_1*256 + temp_0; // 0x64 = 100.
                adc_cnt_tx=temp_1*256 + temp_0;
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

void user_10ms_cb (timer_callback_args_t * p_args)
{
    if (TIMER_EVENT_CYCLE_END == p_args->event)
    {
        /* Add application code to be called periodically here. */

        gb1ms_cycle = 1;
// CHECK FREQ //
//        if (reverse==0){
//            R_BSP_PinAccessEnable();
//            R_BSP_PinWrite(BSP_IO_PORT_01_PIN_00, BSP_IO_LEVEL_HIGH);  //BSP_IO_LEVEL_LOW           /* Protect PFS registers */
//            R_BSP_PinAccessDisable();
//        }
//        if (reverse==1){
//                    R_BSP_PinAccessEnable();
//                    R_BSP_PinWrite(BSP_IO_PORT_01_PIN_00, BSP_IO_LEVEL_LOW);  //BSP_IO_LEVEL_LOW           /* Protect PFS registers */
//                    R_BSP_PinAccessDisable();
//                }
//        reverse = !reverse;
// CHECK FREQ //
    }
}
/*******************************************************************************************************************//**
 * @} (end addtogroup hal_entry)
 **********************************************************************************************************************/

