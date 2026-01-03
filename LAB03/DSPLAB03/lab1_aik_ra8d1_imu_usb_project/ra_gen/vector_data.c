/* generated vector source file - do not edit */
#include "bsp_api.h"
/* Do not build these data structures if no interrupts are currently allocated because IAR will have build errors. */
#if VECTOR_DATA_IRQ_COUNT > 0
        BSP_DONT_REMOVE const fsp_vector_t g_vector_table[BSP_ICU_VECTOR_MAX_ENTRIES] BSP_PLACE_IN_SECTION(BSP_SECTION_APPLICATION_VECTORS) =
        {
                        [0] = usbfs_interrupt_handler, /* USBFS INT (USBFS interrupt) */
            [1] = usbfs_resume_handler, /* USBFS RESUME (USBFS resume interrupt) */
            [2] = usbfs_d0fifo_handler, /* USBFS FIFO 0 (DMA/DTC transfer request 0) */
            [3] = usbfs_d1fifo_handler, /* USBFS FIFO 1 (DMA/DTC transfer request 1) */
            [4] = usbhs_interrupt_handler, /* USBHS USB INT RESUME (USBHS interrupt) */
            [5] = usbhs_d0fifo_handler, /* USBHS FIFO 0 (DMA transfer request 0) */
            [6] = usbhs_d1fifo_handler, /* USBHS FIFO 1 (DMA transfer request 1) */
            [7] = r_icu_isr, /* ICU IRQ11 (External pin interrupt 11) */
            [8] = iic_master_rxi_isr, /* IIC1 RXI (Receive data full) */
            [9] = iic_master_txi_isr, /* IIC1 TXI (Transmit data empty) */
            [10] = iic_master_tei_isr, /* IIC1 TEI (Transmit end) */
            [11] = iic_master_eri_isr, /* IIC1 ERI (Transfer error) */
            [12] = agt_int_isr, /* AGT0 INT (AGT interrupt) */
            [13] = sci_b_uart_rxi_isr, /* SCI3 RXI (Receive data full) */
            [14] = sci_b_uart_txi_isr, /* SCI3 TXI (Transmit data empty) */
            [15] = sci_b_uart_tei_isr, /* SCI3 TEI (Transmit end) */
            [16] = sci_b_uart_eri_isr, /* SCI3 ERI (Receive error) */
        };
        #if BSP_FEATURE_ICU_HAS_IELSR
        const bsp_interrupt_event_t g_interrupt_event_link_select[BSP_ICU_VECTOR_MAX_ENTRIES] =
        {
            [0] = BSP_PRV_VECT_ENUM(EVENT_USBFS_INT,GROUP0), /* USBFS INT (USBFS interrupt) */
            [1] = BSP_PRV_VECT_ENUM(EVENT_USBFS_RESUME,GROUP1), /* USBFS RESUME (USBFS resume interrupt) */
            [2] = BSP_PRV_VECT_ENUM(EVENT_USBFS_FIFO_0,GROUP2), /* USBFS FIFO 0 (DMA/DTC transfer request 0) */
            [3] = BSP_PRV_VECT_ENUM(EVENT_USBFS_FIFO_1,GROUP3), /* USBFS FIFO 1 (DMA/DTC transfer request 1) */
            [4] = BSP_PRV_VECT_ENUM(EVENT_USBHS_USB_INT_RESUME,GROUP4), /* USBHS USB INT RESUME (USBHS interrupt) */
            [5] = BSP_PRV_VECT_ENUM(EVENT_USBHS_FIFO_0,GROUP5), /* USBHS FIFO 0 (DMA transfer request 0) */
            [6] = BSP_PRV_VECT_ENUM(EVENT_USBHS_FIFO_1,GROUP6), /* USBHS FIFO 1 (DMA transfer request 1) */
            [7] = BSP_PRV_VECT_ENUM(EVENT_ICU_IRQ11,GROUP7), /* ICU IRQ11 (External pin interrupt 11) */
            [8] = BSP_PRV_VECT_ENUM(EVENT_IIC1_RXI,GROUP0), /* IIC1 RXI (Receive data full) */
            [9] = BSP_PRV_VECT_ENUM(EVENT_IIC1_TXI,GROUP1), /* IIC1 TXI (Transmit data empty) */
            [10] = BSP_PRV_VECT_ENUM(EVENT_IIC1_TEI,GROUP2), /* IIC1 TEI (Transmit end) */
            [11] = BSP_PRV_VECT_ENUM(EVENT_IIC1_ERI,GROUP3), /* IIC1 ERI (Transfer error) */
            [12] = BSP_PRV_VECT_ENUM(EVENT_AGT0_INT,GROUP4), /* AGT0 INT (AGT interrupt) */
            [13] = BSP_PRV_VECT_ENUM(EVENT_SCI3_RXI,GROUP5), /* SCI3 RXI (Receive data full) */
            [14] = BSP_PRV_VECT_ENUM(EVENT_SCI3_TXI,GROUP6), /* SCI3 TXI (Transmit data empty) */
            [15] = BSP_PRV_VECT_ENUM(EVENT_SCI3_TEI,GROUP7), /* SCI3 TEI (Transmit end) */
            [16] = BSP_PRV_VECT_ENUM(EVENT_SCI3_ERI,GROUP0), /* SCI3 ERI (Receive error) */
        };
        #endif
        #endif
