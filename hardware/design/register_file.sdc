## Generated SDC file "register_file.sdc"

## Copyright (C) 2020  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 20.1.0 Build 711 06/05/2020 SJ Lite Edition"

## DATE    "Fri Mar 01 11:37:56 2024"

##
## DEVICE  "5CSEMA5F31C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name clk -period 20 [get_ports {clk_i}]
create_clock -name clk_virt -period 20


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -clock clk_virt -max 0.550 [get_ports {av_read_i}]
set_input_delay -clock clk_virt -min 0.350 [get_ports {av_read_i}]
set_input_delay -clock clk_virt -max 2.000 [get_ports {av_address_i[*]}]
set_input_delay -clock clk_virt -min 1.500 [get_ports {av_address_i[*]}]
set_input_delay -clock clk_virt -max 0.550 [get_ports {av_write_i}]
set_input_delay -clock clk_virt -min 0.350 [get_ports {av_write_i}]
set_input_delay -clock clk_virt -max 2.000 [get_ports {av_writedata_i[*]}]
set_input_delay -clock clk_virt -min 1.500 [get_ports {av_writedata_i[*]}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -clock clk_virt -max 0.550 [get_ports {av_readdata_o[*]}]
set_output_delay -clock clk_virt -min 0.350 [get_ports {av_readdata_o[*]}]
set_output_delay -clock clk_virt -max 0.550 [get_ports {interrupt_o}]
set_output_delay -clock clk_virt -min 0.350 [get_ports {interrupt_o}]
set_output_delay -clock clk_virt -max 0.550 [get_ports {sys_output_o}]
set_output_delay -clock clk_virt -min 0.350 [get_ports {sys_output_o}]
set_output_delay -clock clk_virt -max 0.550 [get_ports {av_waitrequest_o}]
set_output_delay -clock clk_virt -min 0.350 [get_ports {av_waitrequest_o}]
set_output_delay -clock clk_virt -max 0.550 [get_ports {av_response_o[*]}]
set_output_delay -clock clk_virt -min 0.350 [get_ports {av_response_o[*]}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_ports {rst_i}] -to [all_registers]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

