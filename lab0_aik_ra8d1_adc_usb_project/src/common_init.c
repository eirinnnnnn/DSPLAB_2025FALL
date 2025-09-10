/***********************************************************************************************************************
 * File Name    : common_init.c
 * Description  : Common init function.
 **********************************************************************************************************************/
/***********************************************************************************************************************
* Copyright (c) 2020 - 2024 Renesas Electronics Corporation and/or its affiliates
*
* SPDX-License-Identifier: BSD-3-Clause
***********************************************************************************************************************/

#include "common_init.h"
#include "board_cfg.h"



#define NUM_RATES             (sizeof(pwm_rates) / sizeof(pwm_rates[0]))
#define NUM_DCS               (sizeof(pwm_dcs) / sizeof(pwm_dcs[0]))


fsp_err_t common_init(void)
{
    fsp_err_t fsp_err = FSP_SUCCESS;

//    fsp_err = GPT_Initialize();
//    if(FSP_SUCCESS != fsp_err)
//        return fsp_err;
//
//    fsp_err = ICU_Initialize();
//    if(FSP_SUCCESS != fsp_err)
//        return fsp_err;
//
//    fsp_err = ADC_Initialize();
//    if(FSP_SUCCESS != fsp_err)
//        return fsp_err;

    return fsp_err;
}
