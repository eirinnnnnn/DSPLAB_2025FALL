/* generated common source file - do not edit */
#include "common_data.h"
dtc_instance_ctrl_t g_transfer0_ctrl;

#if (1 == 1)
transfer_info_t g_transfer0_info DTC_TRANSFER_INFO_ALIGNMENT =
{ .transfer_settings_word_b.dest_addr_mode = TRANSFER_ADDR_MODE_FIXED,
  .transfer_settings_word_b.repeat_area = TRANSFER_REPEAT_AREA_SOURCE,
  .transfer_settings_word_b.irq = TRANSFER_IRQ_END,
  .transfer_settings_word_b.chain_mode = TRANSFER_CHAIN_MODE_DISABLED,
  .transfer_settings_word_b.src_addr_mode = TRANSFER_ADDR_MODE_INCREMENTED,
  .transfer_settings_word_b.size = TRANSFER_SIZE_1_BYTE,
  .transfer_settings_word_b.mode = TRANSFER_MODE_NORMAL,
  .p_dest = (void*) NULL,
  .p_src = (void const*) NULL,
  .num_blocks = (uint16_t) 0,
  .length = (uint16_t) 0, };

#elif (1 > 1)
/* User is responsible to initialize the array. */
transfer_info_t g_transfer0_info[1] DTC_TRANSFER_INFO_ALIGNMENT;
#else
/* User must call api::reconfigure before enable DTC transfer. */
#endif

const dtc_extended_cfg_t g_transfer0_cfg_extend =
{ .activation_source = VECTOR_NUMBER_IIC1_TXI, };

const transfer_cfg_t g_transfer0_cfg =
{
#if (1 == 1)
  .p_info = &g_transfer0_info,
#elif (1 > 1)
    .p_info              = g_transfer0_info,
#else
    .p_info = NULL,
#endif
  .p_extend = &g_transfer0_cfg_extend, };

/* Instance structure to use this module. */
const transfer_instance_t g_transfer0 =
{ .p_ctrl = &g_transfer0_ctrl, .p_cfg = &g_transfer0_cfg, .p_api = &g_transfer_on_dtc };
iic_master_instance_ctrl_t g_i2c_master1_ctrl;
const iic_master_extended_cfg_t g_i2c_master1_extend =
{ .timeout_mode = IIC_MASTER_TIMEOUT_MODE_SHORT,
  .timeout_scl_low = IIC_MASTER_TIMEOUT_SCL_LOW_ENABLED,
  .smbus_operation = 0,
  /* Actual calculated bitrate: 98945. Actual calculated duty cycle: 51%. */.clock_settings.brl_value = 15,
  .clock_settings.brh_value = 16,
  .clock_settings.cks_value = 4,
  .clock_settings.sddl_value = 0,
  .clock_settings.dlcs_value = 0, };
const i2c_master_cfg_t g_i2c_master1_cfg =
{ .channel = 1, .rate = I2C_MASTER_RATE_STANDARD, .slave = 0x68, .addr_mode = I2C_MASTER_ADDR_MODE_7BIT,
#define RA_NOT_DEFINED (1)
#if (RA_NOT_DEFINED == g_transfer0)
                .p_transfer_tx       = NULL,
#else
  .p_transfer_tx = &g_transfer0,
#endif
#if (RA_NOT_DEFINED == RA_NOT_DEFINED)
  .p_transfer_rx = NULL,
#else
                .p_transfer_rx       = &RA_NOT_DEFINED,
#endif
#undef RA_NOT_DEFINED
  .p_callback = rm_comms_i2c_callback,
  .p_context = NULL,
#if defined(VECTOR_NUMBER_IIC1_RXI)
    .rxi_irq             = VECTOR_NUMBER_IIC1_RXI,
#else
  .rxi_irq = FSP_INVALID_VECTOR,
#endif
#if defined(VECTOR_NUMBER_IIC1_TXI)
    .txi_irq             = VECTOR_NUMBER_IIC1_TXI,
#else
  .txi_irq = FSP_INVALID_VECTOR,
#endif
#if defined(VECTOR_NUMBER_IIC1_TEI)
    .tei_irq             = VECTOR_NUMBER_IIC1_TEI,
#else
  .tei_irq = FSP_INVALID_VECTOR,
#endif
#if defined(VECTOR_NUMBER_IIC1_ERI)
    .eri_irq             = VECTOR_NUMBER_IIC1_ERI,
#else
  .eri_irq = FSP_INVALID_VECTOR,
#endif
  .ipl = (12),
  .p_extend = &g_i2c_master1_extend, };
/* Instance structure to use this module. */
const i2c_master_instance_t g_i2c_master1 =
{ .p_ctrl = &g_i2c_master1_ctrl, .p_cfg = &g_i2c_master1_cfg, .p_api = &g_i2c_master_on_iic };
#if BSP_CFG_RTOS
#if BSP_CFG_RTOS == 1
#if !defined(g_comms_i2c_bus1_recursive_mutex)
TX_MUTEX g_comms_i2c_bus1_recursive_mutex_handle;
CHAR g_comms_i2c_bus1_recursive_mutex_name[] = "g_comms_i2c_bus1 recursive mutex";
#endif
#if !defined(g_comms_i2c_bus1_blocking_semaphore)
TX_SEMAPHORE g_comms_i2c_bus1_blocking_semaphore_handle;
CHAR g_comms_i2c_bus1_blocking_semaphore_name[] = "g_comms_i2c_bus1 blocking semaphore";
#endif
#elif BSP_CFG_RTOS == 2
#if !defined(g_comms_i2c_bus1_recursive_mutex)
SemaphoreHandle_t g_comms_i2c_bus1_recursive_mutex_handle;
StaticSemaphore_t g_comms_i2c_bus1_recursive_mutex_memory;
#endif
#if !defined(g_comms_i2c_bus1_blocking_semaphore)
SemaphoreHandle_t g_comms_i2c_bus1_blocking_semaphore_handle;
StaticSemaphore_t g_comms_i2c_bus1_blocking_semaphore_memory;
#endif
#endif

#if !defined(g_comms_i2c_bus1_recursive_mutex)
/* Recursive Mutex for I2C bus */
rm_comms_i2c_mutex_t g_comms_i2c_bus1_recursive_mutex =
{
    .p_mutex_handle = &g_comms_i2c_bus1_recursive_mutex_handle,
#if BSP_CFG_RTOS == 1 // ThradX
    .p_mutex_name = &g_comms_i2c_bus1_recursive_mutex_name[0],
#elif BSP_CFG_RTOS == 2 // FreeRTOS
    .p_mutex_memory = &g_comms_i2c_bus1_recursive_mutex_memory,
#endif
};
#endif

#if !defined(g_comms_i2c_bus1_blocking_semaphore)
/* Semaphore for blocking */
rm_comms_i2c_semaphore_t g_comms_i2c_bus1_blocking_semaphore =
{
    .p_semaphore_handle = &g_comms_i2c_bus1_blocking_semaphore_handle,
#if BSP_CFG_RTOS == 1 // ThreadX
    .p_semaphore_name = &g_comms_i2c_bus1_blocking_semaphore_name[0],
#elif BSP_CFG_RTOS == 2 // FreeRTOS
    .p_semaphore_memory = &g_comms_i2c_bus1_blocking_semaphore_memory,
#endif
};
#endif
#endif

/* Shared I2C Bus */
#define RA_NOT_DEFINED (1)
rm_comms_i2c_bus_extended_cfg_t g_comms_i2c_bus1_extended_cfg =
{
#if !defined(g_i2c_master1)
  .p_driver_instance = (void*) &g_i2c_master1,
#elif !defined(RA_NOT_DEFINED)
    .p_driver_instance      = (void*)&RA_NOT_DEFINED,
#elif !defined(RA_NOT_DEFINED)
    .p_driver_instance      = (void*)&RA_NOT_DEFINED,
#endif
  .p_current_ctrl = NULL,
  .bus_timeout = 0xFFFFFFFF,
#if BSP_CFG_RTOS
#if !defined(g_comms_i2c_bus1_blocking_semaphore)
    .p_blocking_semaphore = &g_comms_i2c_bus1_blocking_semaphore,
#if !defined(g_comms_i2c_bus1_recursive_mutex)
    .p_bus_recursive_mutex = &g_comms_i2c_bus1_recursive_mutex,
#else
    .p_bus_recursive_mutex = NULL,
#endif
#else
    .p_bus_recursive_mutex = NULL,
    .p_blocking_semaphore = NULL,
#endif
#else
#endif

#if (0)
    .p_elc = (void*)&g_elc,
    .p_timer = (void*)&g_timer,
#else
  .p_elc = NULL,
  .p_timer = NULL,
#endif
        };
icu_instance_ctrl_t g_external_irq11_pmod1_ctrl;
const external_irq_cfg_t g_external_irq11_pmod1_cfg =
{ .channel = 11, .trigger = EXTERNAL_IRQ_TRIG_FALLING, .filter_enable = true, .clock_source_div =
          EXTERNAL_IRQ_CLOCK_SOURCE_DIV_32,
  .p_callback = i2c_api_icm42670_irq_callback,
  /** If NULL then do not add & */
#if defined(NULL)
    .p_context           = NULL,
#else
  .p_context = &NULL,
#endif
  .p_extend = NULL,
  .ipl = (12),
#if defined(VECTOR_NUMBER_ICU_IRQ11)
    .irq                 = VECTOR_NUMBER_ICU_IRQ11,
#else
  .irq = FSP_INVALID_VECTOR,
#endif
        };
/* Instance structure to use this module. */
const external_irq_instance_t g_external_irq11_pmod1 =
{ .p_ctrl = &g_external_irq11_pmod1_ctrl, .p_cfg = &g_external_irq11_pmod1_cfg, .p_api = &g_external_irq_on_icu };
ioport_instance_ctrl_t g_ioport_ctrl;
const ioport_instance_t g_ioport =
{ .p_api = &g_ioport_on_ioport, .p_ctrl = &g_ioport_ctrl, .p_cfg = &g_bsp_pin_cfg, };
void g_common_init(void)
{
}
