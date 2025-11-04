# ---------- Clock ----------
# You set CLOCK_PERIOD = 50 (20 MHz). Keep it consistent here.
create_clock -name clk -period 50.000 [get_ports clk]

# ---------- Reset ----------
# If your reset is truly asynchronous to clk, mark it as false path.
# (Your RTL treats rst as async input; safe to cut timing.)
set_false_path -from [get_ports rst]

# ---------- Basic I/O assumptions ----------
# Give the tools reasonable defaults (helps buffer sizing and STA).
# Drive strength for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]

# Input transition and output load (rough but safe)
set_input_transition 0.10 [all_inputs]
set_load 0.10 [all_outputs]

# Keep fanout sensible during synth & opt
set_max_fanout 8 [current_design]

# (Optional) If your Wishbone comes from a slower domain, you can relax those paths:
# set_input_delay  5.0 -clock clk [get_ports {wbs_*}]
# set_output_delay 5.0 -clock clk [get_ports {wbs_*}]
