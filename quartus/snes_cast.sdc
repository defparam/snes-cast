
set_time_format -unit ns -decimal_places 3

create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {clk} -period 10.000 -waveform { 0.000 5.000 } [get_ports {clk}]
create_clock -name {FTDI_clk} -period 10.0 -waveform { 0.000 5.000 } [get_ports {FTDI_clk}]

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 







