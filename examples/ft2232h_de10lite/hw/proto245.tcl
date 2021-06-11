# Copyright (C) 2019  Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions 
# and other software and tools, and any partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License 
# Subscription Agreement, the Intel Quartus Prime License Agreement,
# the Intel FPGA IP License Agreement, or other applicable license
# agreement, including, without limitation, that your use is for
# the sole purpose of programming logic devices manufactured by
# Intel and sold by Intel or its authorized distributors.  Please
# refer to the applicable agreement for further details, at
# https://fpgasoftware.intel.com/eula.

# Quartus Prime: Generate Tcl File for Project
# File: proto245.tcl
# Generated on: Fri Jun 11 23:16:25 2021

# Load Quartus Prime Tcl Project package
package require ::quartus::project

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "proto245"]} {
		puts "Project proto245 is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists proto245]} {
		project_open -revision top proto245
	} else {
		project_new -revision top proto245
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
	set_global_assignment -name FAMILY "MAX 10 FPGA"
	set_global_assignment -name DEVICE 10M50DAF484C7G
	set_global_assignment -name ORIGINAL_QUARTUS_VERSION 19.1.0
	set_global_assignment -name PROJECT_CREATION_TIME_DATE "20:50:27  июня 05, 2021"
	set_global_assignment -name LAST_QUARTUS_VERSION "19.1.0 Lite Edition"
	set_global_assignment -name DEVICE_FILTER_PACKAGE FBGA
	set_global_assignment -name DEVICE_FILTER_PIN_COUNT 484
	set_global_assignment -name DEVICE_FILTER_SPEED_GRADE 6
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
	set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
	set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
	set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
	set_global_assignment -name EDA_DESIGN_ENTRY_SYNTHESIS_TOOL "Precision Synthesis"
	set_global_assignment -name EDA_LMF_FILE mentor.lmf -section_id eda_design_synthesis
	set_global_assignment -name EDA_INPUT_DATA_FORMAT VQM -section_id eda_design_synthesis
	set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_timing
	set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_symbol
	set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_signal_integrity
	set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_boundary_scan
	set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
	set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
	set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
	set_global_assignment -name SYSTEMVERILOG_FILE ../../../src/proto245s.sv
	set_global_assignment -name SYSTEMVERILOG_FILE ../../../src/fifo_sync.sv
	set_global_assignment -name SYSTEMVERILOG_FILE ../../../src/fifo_async.sv
	set_global_assignment -name SYSTEMVERILOG_FILE ../../../src/dpram.sv
	set_global_assignment -name SYSTEMVERILOG_FILE top.sv
	set_global_assignment -name SDC_FILE top.sdc
	set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
	set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
	set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005
	set_global_assignment -name VERILOG_SHOW_LMF_MAPPING_MESSAGES OFF
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to max10_clk1_50
	set_location_assignment PIN_P11 -to max10_clk1_50
	set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to key[0]
	set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to key[1]
	set_location_assignment PIN_B8 -to key[0]
	set_location_assignment PIN_A7 -to key[1]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[0]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[1]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[2]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[3]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[4]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[5]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[6]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[7]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[8]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw[9]
	set_location_assignment PIN_C10 -to sw[0]
	set_location_assignment PIN_C11 -to sw[1]
	set_location_assignment PIN_D12 -to sw[2]
	set_location_assignment PIN_C12 -to sw[3]
	set_location_assignment PIN_A12 -to sw[4]
	set_location_assignment PIN_B12 -to sw[5]
	set_location_assignment PIN_A13 -to sw[6]
	set_location_assignment PIN_A14 -to sw[7]
	set_location_assignment PIN_B14 -to sw[8]
	set_location_assignment PIN_F15 -to sw[9]
	# gpio[0]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_oen -comment gpio[0]
	# gpio[2]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_clk -comment gpio[2]
	# gpio[4]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_siwu -comment gpio[4]
	# gpio[6]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_wrn -comment gpio[6]
	# gpio[8]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_rdn -comment gpio[8]
	# gpio[10]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_txen -comment gpio[10]
	# gpio[12]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_rxfn -comment gpio[12]
	# gpio[14]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[7] -comment gpio[14]
	# gpio[16]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[6] -comment gpio[16]
	# gpio[18]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[5] -comment gpio[18]
	# gpio[20]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[4] -comment gpio[20]
	# gpio[22]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[3] -comment gpio[22]
	# gpio[24]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[2] -comment gpio[24]
	# gpio[26]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[1] -comment gpio[26]
	# gpio[28]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ft_data[0] -comment gpio[28]
	# gpio[0]
	set_location_assignment PIN_V10 -to ft_oen -comment gpio[0]
	# gpio[2]
	set_location_assignment PIN_V9 -to ft_clk -comment gpio[2]
	# gpio[4]
	set_location_assignment PIN_V8 -to ft_siwu -comment gpio[4]
	# gpio[6]
	set_location_assignment PIN_V7 -to ft_wrn -comment gpio[6]
	# gpio[8]
	set_location_assignment PIN_W6 -to ft_rdn -comment gpio[8]
	# gpio[10]
	set_location_assignment PIN_W5 -to ft_txen -comment gpio[10]
	# gpio[12]
	set_location_assignment PIN_AA14 -to ft_rxfn -comment gpio[12]
	# gpio[14]
	set_location_assignment PIN_W12 -to ft_data[7] -comment gpio[14]
	# gpio[16]
	set_location_assignment PIN_AB12 -to ft_data[6] -comment gpio[16]
	# gpio[18]
	set_location_assignment PIN_AB11 -to ft_data[5] -comment gpio[18]
	# gpio[20]
	set_location_assignment PIN_AB10 -to ft_data[4] -comment gpio[20]
	# gpio[22]
	set_location_assignment PIN_AA9 -to ft_data[3] -comment gpio[22]
	# gpio[24]
	set_location_assignment PIN_AA8 -to ft_data[2] -comment gpio[24]
	# gpio[26]
	set_location_assignment PIN_AA7 -to ft_data[1] -comment gpio[26]
	# gpio[28]
	set_location_assignment PIN_AA6 -to ft_data[0] -comment gpio[28]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[0]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[1]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[2]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[3]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[4]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[5]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[6]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[7]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[8]
	set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledr[9]
	set_location_assignment PIN_A8 -to ledr[0]
	set_location_assignment PIN_A9 -to ledr[1]
	set_location_assignment PIN_A10 -to ledr[2]
	set_location_assignment PIN_B10 -to ledr[3]
	set_location_assignment PIN_D13 -to ledr[4]
	set_location_assignment PIN_C13 -to ledr[5]
	set_location_assignment PIN_E14 -to ledr[6]
	set_location_assignment PIN_D14 -to ledr[7]
	set_location_assignment PIN_A11 -to ledr[8]
	set_location_assignment PIN_B11 -to ledr[9]
	set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
