################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_abs.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_access.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_dma.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_hostelectrical.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_abs.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_access.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_mcu.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_abs.c \
../ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_access.c 

C_DEPS += \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_abs.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_access.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_dma.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hostelectrical.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_abs.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_access.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_mcu.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_abs.d \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_access.d 

OBJS += \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_abs.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_creg_access.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_dma.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hostelectrical.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_abs.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_hreg_access.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_mcu.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_abs.o \
./ra/fsp/src/r_usb_basic/src/hw/r_usb_preg_access.o 

SREC += \
lab0_aik_ra8d1_adc_usb_project.srec 

MAP += \
lab0_aik_ra8d1_adc_usb_project.map 


# Each subdirectory must supply rules for building sources it contributes
ra/fsp/src/r_usb_basic/src/hw/%.o: ../ra/fsp/src/r_usb_basic/src/hw/%.c
	$(file > $@.in,-mthumb -mfloat-abi=hard -mcpu=cortex-m85+nopacbti -O2 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -fno-strict-aliasing -Wunused -Wuninitialized -Wall -Wextra -Wmissing-declarations -Wconversion -Wpointer-arith -Wshadow -Wlogical-op -Waggregate-return -Wfloat-equal -g -D_RENESAS_RA_ -D_RA_CORE=CM85 -D_RA_ORDINAL=1 -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/src" -I"." -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc/api" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc/instances" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/arm/CMSIS_6/CMSIS/Core/Include" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_gen" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_cfg/fsp_cfg/bsp" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_cfg/fsp_cfg" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/src/r_usb_basic/src/driver/inc" -std=c99 -Wno-stringop-overflow -Wno-format-truncation -flax-vector-conversions --param=min-pagesize=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" -x c "$<")
	@echo Building file: $< && arm-none-eabi-gcc @"$@.in"

