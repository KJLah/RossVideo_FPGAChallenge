# Clock (27MHz on Tang Nano 9K)
set_property PACKAGE_PIN 52 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset button (active high, directly usable)
set_property PACKAGE_PIN 4 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# VGA sync signals
set_property PACKAGE_PIN 25 [get_ports hsync]
set_property PACKAGE_PIN 26 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

# RGB output (accent accent accent accent accent 3-bit VGA)
set_property PACKAGE_PIN 27 [get_ports {rgb[2]}]
set_property PACKAGE_PIN 28 [get_ports {rgb[1]}]
set_property PACKAGE_PIN 29 [get_ports {rgb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[*]}]
