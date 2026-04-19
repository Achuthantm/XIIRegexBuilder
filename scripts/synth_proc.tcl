# VIVADO SYNTHESIS & BITSTREAM SCRIPT
# This script automates the flow for the Regex Processor hardware

# 1. Setup
set part xc7a100tcsg324-1
set outputDir ./processor/build
file mkdir $outputDir

# 2. Read Verilog files
read_verilog processor/regex_cpu.v
read_verilog processor/uart.v
read_verilog processor/top_level.v

# 3. Read Constraints
read_xdc processor/constraints.xdc

# 4. Add memory files
set_property DESIGN_MODE RTL [current_fileset]
add_files -norecurse processor/build/imem.hex
set_property file_type {Memory Initialization Files} [get_files processor/build/imem.hex]

# 5. Run Synthesis
synth_design -top top_level -part $part

# 6. Run Implementation Flow
opt_design
place_design
route_design

# 7. Generate Reports
report_utilization -file $outputDir/utilization.txt
report_timing_summary -file $outputDir/timing.txt

# 8. Generate Bitstream
write_bitstream -force $outputDir/top_fpga.bit
