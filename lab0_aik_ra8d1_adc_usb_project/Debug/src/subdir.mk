################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/common_init.c \
../src/hal_entry.c \
../src/r_usb_pcdc_descriptor.c 

C_DEPS += \
./src/common_init.d \
./src/hal_entry.d \
./src/r_usb_pcdc_descriptor.d 

OBJS += \
./src/common_init.o \
./src/hal_entry.o \
./src/r_usb_pcdc_descriptor.o 

SREC += \
lab0_aik_ra8d1_adc_usb_project.srec 

MAP += \
lab0_aik_ra8d1_adc_usb_project.map 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	$(file > $@.in,-mthumb -mfloat-abi=hard -mcpu=cortex-m85+nopacbti -O2 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -fno-strict-aliasing -Wunused -Wuninitialized -Wall -Wextra -Wmissing-declarations -Wconversion -Wpointer-arith -Wshadow -Wlogical-op -Waggregate-return -Wfloat-equal -g -D_RENESAS_RA_ -D_RA_CORE=CM85 -D_RA_ORDINAL=1 -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/src" -I"." -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc/api" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/inc/instances" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/arm/CMSIS_6/CMSIS/Core/Include" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_gen" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_cfg/fsp_cfg/bsp" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra_cfg/fsp_cfg" -I"Z:/UserData/Desktop/DSPLAB2025Fall/lab0_aik_ra8d1_adc_usb_project/ra/fsp/src/r_usb_basic/src/driver/inc" -std=c99 -Wno-stringop-overflow -Wno-format-truncation -flax-vector-conversions --param=min-pagesize=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" -x c "$<")
	@echo Building file: $< && arm-none-eabi-gcc @"$@.in"

