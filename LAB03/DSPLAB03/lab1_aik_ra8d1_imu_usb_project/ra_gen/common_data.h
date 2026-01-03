/* generated common header file - do not edit */
#ifndef COMMON_DATA_H_
#define COMMON_DATA_H_
#include <stdint.h>
#include "bsp_api.h"
#include "r_dtc.h"
#include "r_transfer_api.h"
#include "r_iic_master.h"
#include "r_i2c_master_api.h"
#include "rm_comms_i2c.h"
#include "rm_comms_api.h"
#include "r_icu.h"
#include "r_external_irq_api.h"
#include "r_ioport.h"
#include "bsp_pin_cfg.h"
FSP_HEADER
/* Transfer on DTC Instance. */
extern const transfer_instance_t g_transfer0;

/** Access the DTC instance using these structures when calling API functions directly (::p_api is not used). */
extern dtc_instance_ctrl_t g_transfer0_ctrl;
extern const transfer_cfg_t g_transfer0_cfg;
/* I2C Master on IIC Instance. */
extern const i2c_master_instance_t g_i2c_master1;

/** Access the I2C Master instance using these structures when calling API functions directly (::p_api is not used). */
extern iic_master_instance_ctrl_t g_i2c_master1_ctrl;
extern const i2c_master_cfg_t g_i2c_master1_cfg;

#ifndef rm_comms_i2c_callback
void rm_comms_i2c_callback(i2c_master_callback_args_t *p_args);
#endif
/* I2C Shared Bus */
extern rm_comms_i2c_bus_extended_cfg_t g_comms_i2c_bus1_extended_cfg;
/** External IRQ on ICU Instance. */
extern const external_irq_instance_t g_external_irq11_pmod1;

/** Access the ICU instance using these structures when calling API functions directly (::p_api is not used). */
extern icu_instance_ctrl_t g_external_irq11_pmod1_ctrl;
extern const external_irq_cfg_t g_external_irq11_pmod1_cfg;

#ifndef i2c_api_icm42670_irq_callback
void i2c_api_icm42670_irq_callback(external_irq_callback_args_t *p_args);
#endif
#define IOPORT_CFG_NAME g_bsp_pin_cfg
#define IOPORT_CFG_OPEN R_IOPORT_Open
#define IOPORT_CFG_CTRL g_ioport_ctrl

/* IOPORT Instance */
extern const ioport_instance_t g_ioport;

/* IOPORT control structure. */
extern ioport_instance_ctrl_t g_ioport_ctrl;
void g_common_init(void);
FSP_FOOTER
#endif /* COMMON_DATA_H_ */
