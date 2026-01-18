set_property SRC_FILE_INFO {cfile:c:/Users/ahmed/Downloads/uOttaHack_FPGA/fpga_top/fpga_top.gen/sources_1/ip/clk_125m_pll/clk_125m_pll.xdc rfile:../../../fpga_top.gen/sources_1/ip/clk_125m_pll/clk_125m_pll.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:54 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.400
