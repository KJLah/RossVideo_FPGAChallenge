# Tang Nano 9K Constraints for fpga_top (ECG Display)
# Board: Sipeed Tang Nano 9K (GW1NR-9C)

# System Clock (27MHz on-board crystal)
set_property PACKAGE_PIN 52 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset Button
set_property PACKAGE_PIN 4 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# VGA Sync Signals
set_property PACKAGE_PIN 77 [get_ports hsync]
set_property PACKAGE_PIN 76 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

# RGB Output (3-bit VGA)
set_property PACKAGE_PIN 75 [get_ports {rgb[2]}]
set_property PACKAGE_PIN 74 [get_ports {rgb[1]}]
set_property PACKAGE_PIN 73 [get_ports {rgb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[0]}]
