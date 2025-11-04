// =============================================================
// 4x4 Weight-Stationary Systolic Array (Verilog-2005)
// - Bottom row outputs are the final results (WS dataflow)
// - Row-gated weight loading: broadcast w_col_* and only the
//   selected row (one-hot) latches on that cycle
// =============================================================
module systolic_array_4x4 #(
  parameter W_BITS       = 8,
  parameter ACC_BITS     = 32,
  parameter PIPELINE_MUL = 0
)(
  input  clk,
  input  rst,
  // control
  input  start,          // (optional; not used internally here)
  input  clear_ps,       // clear accumulators
  input  mac_en,         // enable MAC for all PEs
  input  load_w,         // global "load weights" phase active
  input  [3:0] load_row_en, // one-hot row select during load_w (bit 0=row0 .. bit3=row3)

  // data inputs
  input  signed [W_BITS-1:0] a_row_0,
  input  signed [W_BITS-1:0] a_row_1,
  input  signed [W_BITS-1:0] a_row_2,
  input  signed [W_BITS-1:0] a_row_3,

  input  signed [W_BITS-1:0] w_col_0,
  input  signed [W_BITS-1:0] w_col_1,
  input  signed [W_BITS-1:0] w_col_2,
  input  signed [W_BITS-1:0] w_col_3,

  // status
  output busy,   // optional: tie to mac_en|load_w if you wish
  output done,   // optional: tie low here; wrapper decides "done"

  // bottom-row outputs (final results for WS)
  output signed [ACC_BITS-1:0] c_out_30,
  output signed [ACC_BITS-1:0] c_out_31,
  output signed [ACC_BITS-1:0] c_out_32,
  output signed [ACC_BITS-1:0] c_out_33
);

  // ----- simple busy/done for now; wrapper owns real sequencing -----
  assign busy = load_w | mac_en;
  assign done = 1'b0;

  // ------------------------------------------------------------
  // Interconnect nets: activations propagate to the right,
  // partial sums propagate down.
  // We'll name nets explicitly (no SystemVerilog arrays).
  // act[i][j] is activation between PE(i,j-1) -> PE(i,j)
  // ps[i][j]  is partial sum between PE(i-1,j) -> PE(i,j)
  // Rows: 0..3, Cols: 0..3. Add border wires at left/top.
  // ------------------------------------------------------------

  // Activation left borders (row inputs)
  wire signed [W_BITS-1:0] act_l_0 = a_row_0;
  wire signed [W_BITS-1:0] act_l_1 = a_row_1;
  wire signed [W_BITS-1:0] act_l_2 = a_row_2;
  wire signed [W_BITS-1:0] act_l_3 = a_row_3;

  // Activation internal chain wires
  wire signed [W_BITS-1:0] act_0_0_to_0_1;
  wire signed [W_BITS-1:0] act_0_1_to_0_2;
  wire signed [W_BITS-1:0] act_0_2_to_0_3;

  wire signed [W_BITS-1:0] act_1_0_to_1_1;
  wire signed [W_BITS-1:0] act_1_1_to_1_2;
  wire signed [W_BITS-1:0] act_1_2_to_1_3;

  wire signed [W_BITS-1:0] act_2_0_to_2_1;
  wire signed [W_BITS-1:0] act_2_1_to_2_2;
  wire signed [W_BITS-1:0] act_2_2_to_2_3;

  wire signed [W_BITS-1:0] act_3_0_to_3_1;
  wire signed [W_BITS-1:0] act_3_1_to_3_2;
  wire signed [W_BITS-1:0] act_3_2_to_3_3;

  // Partial-sum top borders (zero into first row)
  wire signed [ACC_BITS-1:0] ps_t_0 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_1 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_2 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_3 = {ACC_BITS{1'b0}};

  // Partial-sum internal chain wires
  wire signed [ACC_BITS-1:0] ps_0_0_to_1_0;
  wire signed [ACC_BITS-1:0] ps_0_1_to_1_1;
  wire signed [ACC_BITS-1:0] ps_0_2_to_1_2;
  wire signed [ACC_BITS-1:0] ps_0_3_to_1_3;

  wire signed [ACC_BITS-1:0] ps_1_0_to_2_0;
  wire signed [ACC_BITS-1:0] ps_1_1_to_2_1;
  wire signed [ACC_BITS-1:0] ps_1_2_to_2_2;
  wire signed [ACC_BITS-1:0] ps_1_3_to_2_3;

  wire signed [ACC_BITS-1:0] ps_2_0_to_3_0;
  wire signed [ACC_BITS-1:0] ps_2_1_to_3_1;
  wire signed [ACC_BITS-1:0] ps_2_2_to_3_2;
  wire signed [ACC_BITS-1:0] ps_2_3_to_3_3;

  // Row-gated load enables per PE row
  wire load_w_r0 = load_w & load_row_en[0];
  wire load_w_r1 = load_w & load_row_en[1];
  wire load_w_r2 = load_w & load_row_en[2];
  wire load_w_r3 = load_w & load_row_en[3];

  // ---------------- Row 0 ----------------
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u00 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_0), .ps_in(ps_t_0),
    .ps_out(ps_0_0_to_1_0), .act_out(act_0_0_to_0_1), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u01 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_0_0_to_0_1), .ps_in(ps_t_1),
    .ps_out(ps_0_1_to_1_1), .act_out(act_0_1_to_0_2), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u02 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_0_1_to_0_2), .ps_in(ps_t_2),
    .ps_out(ps_0_2_to_1_2), .act_out(act_0_2_to_0_3), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u03 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_0_2_to_0_3), .ps_in(ps_t_3),
    .ps_out(ps_0_3_to_1_3), .act_out(/* right edge */), .overflow_flag()
  );

  // ---------------- Row 1 ----------------
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u10 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_1), .ps_in(ps_0_0_to_1_0),
    .ps_out(ps_1_0_to_2_0), .act_out(act_1_0_to_1_1), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u11 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_1_0_to_1_1), .ps_in(ps_0_1_to_1_1),
    .ps_out(ps_1_1_to_2_1), .act_out(act_1_1_to_1_2), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u12 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_1_1_to_1_2), .ps_in(ps_0_2_to_1_2),
    .ps_out(ps_1_2_to_2_2), .act_out(act_1_2_to_1_3), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u13 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_1_2_to_1_3), .ps_in(ps_0_3_to_1_3),
    .ps_out(ps_1_3_to_2_3), .act_out(/* right edge */), .overflow_flag()
  );

  // ---------------- Row 2 ----------------
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u20 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_2), .ps_in(ps_1_0_to_2_0),
    .ps_out(ps_2_0_to_3_0), .act_out(act_2_0_to_2_1), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u21 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_2_0_to_2_1), .ps_in(ps_1_1_to_2_1),
    .ps_out(ps_2_1_to_3_1), .act_out(act_2_1_to_2_2), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u22 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_2_1_to_2_2), .ps_in(ps_1_2_to_2_2),
    .ps_out(ps_2_2_to_3_2), .act_out(act_2_2_to_2_3), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u23 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_2_2_to_2_3), .ps_in(ps_1_3_to_2_3),
    .ps_out(ps_2_3_to_3_3), .act_out(/* right edge */), .overflow_flag()
  );

  // ---------------- Row 3 (bottom) ----------------
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u30 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_3), .ps_in(ps_2_0_to_3_0),
    .ps_out(c_out_30), .act_out(act_3_0_to_3_1), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u31 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_3_0_to_3_1), .ps_in(ps_2_1_to_3_1),
    .ps_out(c_out_31), .act_out(act_3_1_to_3_2), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u32 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_3_1_to_3_2), .ps_in(ps_2_2_to_3_2),
    .ps_out(c_out_32), .act_out(act_3_2_to_3_3), .overflow_flag()
  );
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u33 (
    .clk(clk), .rst(rst),
    .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_3_2_to_3_3), .ps_in(ps_2_3_to_3_3),
    .ps_out(c_out_33), .act_out(/* right edge */), .overflow_flag()
  );

endmodule
