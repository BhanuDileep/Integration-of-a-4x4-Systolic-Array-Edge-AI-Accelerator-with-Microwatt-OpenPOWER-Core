// =============================================================
// 8x8 Weight-Stationary Systolic Array (Verilog-2005)
// Scaled from 4x4 to 8x8 - 64 Processing Elements
// =============================================================
module systolic_array_8x8 #(
  parameter W_BITS       = 8,
  parameter ACC_BITS     = 32,
  parameter PIPELINE_MUL = 0
)(
  input  clk,
  input  rst,
  // control
  input  start,
  input  clear_ps,
  input  mac_en,
  input  load_w,
  input  [7:0] load_row_en, // 8-bit for 8 rows

  // data inputs - 8 rows
  input  signed [W_BITS-1:0] a_row_0,
  input  signed [W_BITS-1:0] a_row_1,
  input  signed [W_BITS-1:0] a_row_2,
  input  signed [W_BITS-1:0] a_row_3,
  input  signed [W_BITS-1:0] a_row_4,
  input  signed [W_BITS-1:0] a_row_5,
  input  signed [W_BITS-1:0] a_row_6,
  input  signed [W_BITS-1:0] a_row_7,

  // weight inputs - 8 columns
  input  signed [W_BITS-1:0] w_col_0,
  input  signed [W_BITS-1:0] w_col_1,
  input  signed [W_BITS-1:0] w_col_2,
  input  signed [W_BITS-1:0] w_col_3,
  input  signed [W_BITS-1:0] w_col_4,
  input  signed [W_BITS-1:0] w_col_5,
  input  signed [W_BITS-1:0] w_col_6,
  input  signed [W_BITS-1:0] w_col_7,

  // status
  output busy,
  output done,

  // bottom-row outputs (row 7, final results)
  output signed [ACC_BITS-1:0] c_out_70,
  output signed [ACC_BITS-1:0] c_out_71,
  output signed [ACC_BITS-1:0] c_out_72,
  output signed [ACC_BITS-1:0] c_out_73,
  output signed [ACC_BITS-1:0] c_out_74,
  output signed [ACC_BITS-1:0] c_out_75,
  output signed [ACC_BITS-1:0] c_out_76,
  output signed [ACC_BITS-1:0] c_out_77
);

  assign busy = load_w | mac_en;
  assign done = 1'b0;

  // ============================================================
  // Activation left borders (row inputs)
  // ============================================================
  wire signed [W_BITS-1:0] act_l_0 = a_row_0;
  wire signed [W_BITS-1:0] act_l_1 = a_row_1;
  wire signed [W_BITS-1:0] act_l_2 = a_row_2;
  wire signed [W_BITS-1:0] act_l_3 = a_row_3;
  wire signed [W_BITS-1:0] act_l_4 = a_row_4;
  wire signed [W_BITS-1:0] act_l_5 = a_row_5;
  wire signed [W_BITS-1:0] act_l_6 = a_row_6;
  wire signed [W_BITS-1:0] act_l_7 = a_row_7;

  // ============================================================
  // Activation horizontal chain wires (8 rows × 7 connections)
  // ============================================================
  // Row 0
  wire signed [W_BITS-1:0] act_0_0_to_0_1, act_0_1_to_0_2, act_0_2_to_0_3;
  wire signed [W_BITS-1:0] act_0_3_to_0_4, act_0_4_to_0_5, act_0_5_to_0_6, act_0_6_to_0_7;
  
  // Row 1
  wire signed [W_BITS-1:0] act_1_0_to_1_1, act_1_1_to_1_2, act_1_2_to_1_3;
  wire signed [W_BITS-1:0] act_1_3_to_1_4, act_1_4_to_1_5, act_1_5_to_1_6, act_1_6_to_1_7;
  
  // Row 2
  wire signed [W_BITS-1:0] act_2_0_to_2_1, act_2_1_to_2_2, act_2_2_to_2_3;
  wire signed [W_BITS-1:0] act_2_3_to_2_4, act_2_4_to_2_5, act_2_5_to_2_6, act_2_6_to_2_7;
  
  // Row 3
  wire signed [W_BITS-1:0] act_3_0_to_3_1, act_3_1_to_3_2, act_3_2_to_3_3;
  wire signed [W_BITS-1:0] act_3_3_to_3_4, act_3_4_to_3_5, act_3_5_to_3_6, act_3_6_to_3_7;
  
  // Row 4
  wire signed [W_BITS-1:0] act_4_0_to_4_1, act_4_1_to_4_2, act_4_2_to_4_3;
  wire signed [W_BITS-1:0] act_4_3_to_4_4, act_4_4_to_4_5, act_4_5_to_4_6, act_4_6_to_4_7;
  
  // Row 5
  wire signed [W_BITS-1:0] act_5_0_to_5_1, act_5_1_to_5_2, act_5_2_to_5_3;
  wire signed [W_BITS-1:0] act_5_3_to_5_4, act_5_4_to_5_5, act_5_5_to_5_6, act_5_6_to_5_7;
  
  // Row 6
  wire signed [W_BITS-1:0] act_6_0_to_6_1, act_6_1_to_6_2, act_6_2_to_6_3;
  wire signed [W_BITS-1:0] act_6_3_to_6_4, act_6_4_to_6_5, act_6_5_to_6_6, act_6_6_to_6_7;
  
  // Row 7
  wire signed [W_BITS-1:0] act_7_0_to_7_1, act_7_1_to_7_2, act_7_2_to_7_3;
  wire signed [W_BITS-1:0] act_7_3_to_7_4, act_7_4_to_7_5, act_7_5_to_7_6, act_7_6_to_7_7;

  // ============================================================
  // Partial-sum top borders (zero into first row)
  // ============================================================
  wire signed [ACC_BITS-1:0] ps_t_0 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_1 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_2 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_3 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_4 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_5 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_6 = {ACC_BITS{1'b0}};
  wire signed [ACC_BITS-1:0] ps_t_7 = {ACC_BITS{1'b0}};

  // ============================================================
  // Partial-sum vertical chain wires (7 rows × 8 columns)
  // ============================================================
  // Row 0 → Row 1
  wire signed [ACC_BITS-1:0] ps_0_0_to_1_0, ps_0_1_to_1_1, ps_0_2_to_1_2, ps_0_3_to_1_3;
  wire signed [ACC_BITS-1:0] ps_0_4_to_1_4, ps_0_5_to_1_5, ps_0_6_to_1_6, ps_0_7_to_1_7;
  
  // Row 1 → Row 2
  wire signed [ACC_BITS-1:0] ps_1_0_to_2_0, ps_1_1_to_2_1, ps_1_2_to_2_2, ps_1_3_to_2_3;
  wire signed [ACC_BITS-1:0] ps_1_4_to_2_4, ps_1_5_to_2_5, ps_1_6_to_2_6, ps_1_7_to_2_7;
  
  // Row 2 → Row 3
  wire signed [ACC_BITS-1:0] ps_2_0_to_3_0, ps_2_1_to_3_1, ps_2_2_to_3_2, ps_2_3_to_3_3;
  wire signed [ACC_BITS-1:0] ps_2_4_to_3_4, ps_2_5_to_3_5, ps_2_6_to_3_6, ps_2_7_to_3_7;
  
  // Row 3 → Row 4
  wire signed [ACC_BITS-1:0] ps_3_0_to_4_0, ps_3_1_to_4_1, ps_3_2_to_4_2, ps_3_3_to_4_3;
  wire signed [ACC_BITS-1:0] ps_3_4_to_4_4, ps_3_5_to_4_5, ps_3_6_to_4_6, ps_3_7_to_4_7;
  
  // Row 4 → Row 5
  wire signed [ACC_BITS-1:0] ps_4_0_to_5_0, ps_4_1_to_5_1, ps_4_2_to_5_2, ps_4_3_to_5_3;
  wire signed [ACC_BITS-1:0] ps_4_4_to_5_4, ps_4_5_to_5_5, ps_4_6_to_5_6, ps_4_7_to_5_7;
  
  // Row 5 → Row 6
  wire signed [ACC_BITS-1:0] ps_5_0_to_6_0, ps_5_1_to_6_1, ps_5_2_to_6_2, ps_5_3_to_6_3;
  wire signed [ACC_BITS-1:0] ps_5_4_to_6_4, ps_5_5_to_6_5, ps_5_6_to_6_6, ps_5_7_to_6_7;
  
  // Row 6 → Row 7
  wire signed [ACC_BITS-1:0] ps_6_0_to_7_0, ps_6_1_to_7_1, ps_6_2_to_7_2, ps_6_3_to_7_3;
  wire signed [ACC_BITS-1:0] ps_6_4_to_7_4, ps_6_5_to_7_5, ps_6_6_to_7_6, ps_6_7_to_7_7;

  // ============================================================
  // Row-gated load enables
  // ============================================================
  wire load_w_r0 = load_w & load_row_en[0];
  wire load_w_r1 = load_w & load_row_en[1];
  wire load_w_r2 = load_w & load_row_en[2];
  wire load_w_r3 = load_w & load_row_en[3];
  wire load_w_r4 = load_w & load_row_en[4];
  wire load_w_r5 = load_w & load_row_en[5];
  wire load_w_r6 = load_w & load_row_en[6];
  wire load_w_r7 = load_w & load_row_en[7];

  // ============================================================
  // PE Instantiations - 64 PEs (8×8 grid)
  // ============================================================
  
  // Row 0 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u00 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_0), .ps_in(ps_t_0),
    .ps_out(ps_0_0_to_1_0), .act_out(act_0_0_to_0_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u01 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_0_0_to_0_1), .ps_in(ps_t_1),
    .ps_out(ps_0_1_to_1_1), .act_out(act_0_1_to_0_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u02 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_0_1_to_0_2), .ps_in(ps_t_2),
    .ps_out(ps_0_2_to_1_2), .act_out(act_0_2_to_0_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u03 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_0_2_to_0_3), .ps_in(ps_t_3),
    .ps_out(ps_0_3_to_1_3), .act_out(act_0_3_to_0_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u04 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_0_3_to_0_4), .ps_in(ps_t_4),
    .ps_out(ps_0_4_to_1_4), .act_out(act_0_4_to_0_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u05 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_0_4_to_0_5), .ps_in(ps_t_5),
    .ps_out(ps_0_5_to_1_5), .act_out(act_0_5_to_0_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u06 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_0_5_to_0_6), .ps_in(ps_t_6),
    .ps_out(ps_0_6_to_1_6), .act_out(act_0_6_to_0_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u07 (
    .clk(clk), .rst(rst), .load_w(load_w_r0), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_0_6_to_0_7), .ps_in(ps_t_7),
    .ps_out(ps_0_7_to_1_7), .act_out(), .overflow_flag());

  // Row 1 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u10 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_1), .ps_in(ps_0_0_to_1_0),
    .ps_out(ps_1_0_to_2_0), .act_out(act_1_0_to_1_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u11 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_1_0_to_1_1), .ps_in(ps_0_1_to_1_1),
    .ps_out(ps_1_1_to_2_1), .act_out(act_1_1_to_1_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u12 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_1_1_to_1_2), .ps_in(ps_0_2_to_1_2),
    .ps_out(ps_1_2_to_2_2), .act_out(act_1_2_to_1_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u13 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_1_2_to_1_3), .ps_in(ps_0_3_to_1_3),
    .ps_out(ps_1_3_to_2_3), .act_out(act_1_3_to_1_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u14 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_1_3_to_1_4), .ps_in(ps_0_4_to_1_4),
    .ps_out(ps_1_4_to_2_4), .act_out(act_1_4_to_1_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u15 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_1_4_to_1_5), .ps_in(ps_0_5_to_1_5),
    .ps_out(ps_1_5_to_2_5), .act_out(act_1_5_to_1_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u16 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_1_5_to_1_6), .ps_in(ps_0_6_to_1_6),
    .ps_out(ps_1_6_to_2_6), .act_out(act_1_6_to_1_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u17 (
    .clk(clk), .rst(rst), .load_w(load_w_r1), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_1_6_to_1_7), .ps_in(ps_0_7_to_1_7),
    .ps_out(ps_1_7_to_2_7), .act_out(), .overflow_flag());

  // Row 2 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u20 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_2), .ps_in(ps_1_0_to_2_0),
    .ps_out(ps_2_0_to_3_0), .act_out(act_2_0_to_2_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u21 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_2_0_to_2_1), .ps_in(ps_1_1_to_2_1),
    .ps_out(ps_2_1_to_3_1), .act_out(act_2_1_to_2_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u22 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_2_1_to_2_2), .ps_in(ps_1_2_to_2_2),
    .ps_out(ps_2_2_to_3_2), .act_out(act_2_2_to_2_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u23 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_2_2_to_2_3), .ps_in(ps_1_3_to_2_3),
    .ps_out(ps_2_3_to_3_3), .act_out(act_2_3_to_2_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u24 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_2_3_to_2_4), .ps_in(ps_1_4_to_2_4),
    .ps_out(ps_2_4_to_3_4), .act_out(act_2_4_to_2_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u25 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_2_4_to_2_5), .ps_in(ps_1_5_to_2_5),
    .ps_out(ps_2_5_to_3_5), .act_out(act_2_5_to_2_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u26 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_2_5_to_2_6), .ps_in(ps_1_6_to_2_6),
    .ps_out(ps_2_6_to_3_6), .act_out(act_2_6_to_2_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u27 (
    .clk(clk), .rst(rst), .load_w(load_w_r2), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_2_6_to_2_7), .ps_in(ps_1_7_to_2_7),
    .ps_out(ps_2_7_to_3_7), .act_out(), .overflow_flag());

  // Row 3 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u30 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_3), .ps_in(ps_2_0_to_3_0),
    .ps_out(ps_3_0_to_4_0), .act_out(act_3_0_to_3_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u31 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_3_0_to_3_1), .ps_in(ps_2_1_to_3_1),
    .ps_out(ps_3_1_to_4_1), .act_out(act_3_1_to_3_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u32 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_3_1_to_3_2), .ps_in(ps_2_2_to_3_2),
    .ps_out(ps_3_2_to_4_2), .act_out(act_3_2_to_3_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u33 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_3_2_to_3_3), .ps_in(ps_2_3_to_3_3),
    .ps_out(ps_3_3_to_4_3), .act_out(act_3_3_to_3_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u34 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_3_3_to_3_4), .ps_in(ps_2_4_to_3_4),
    .ps_out(ps_3_4_to_4_4), .act_out(act_3_4_to_3_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u35 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_3_4_to_3_5), .ps_in(ps_2_5_to_3_5),
    .ps_out(ps_3_5_to_4_5), .act_out(act_3_5_to_3_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u36 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_3_5_to_3_6), .ps_in(ps_2_6_to_3_6),
    .ps_out(ps_3_6_to_4_6), .act_out(act_3_6_to_3_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u37 (
    .clk(clk), .rst(rst), .load_w(load_w_r3), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_3_6_to_3_7), .ps_in(ps_2_7_to_3_7),
    .ps_out(ps_3_7_to_4_7), .act_out(), .overflow_flag());

  // Row 4 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u40 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_4), .ps_in(ps_3_0_to_4_0),
    .ps_out(ps_4_0_to_5_0), .act_out(act_4_0_to_4_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u41 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_4_0_to_4_1), .ps_in(ps_3_1_to_4_1),
    .ps_out(ps_4_1_to_5_1), .act_out(act_4_1_to_4_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u42 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_4_1_to_4_2), .ps_in(ps_3_2_to_4_2),
    .ps_out(ps_4_2_to_5_2), .act_out(act_4_2_to_4_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u43 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_4_2_to_4_3), .ps_in(ps_3_3_to_4_3),
    .ps_out(ps_4_3_to_5_3), .act_out(act_4_3_to_4_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u44 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_4_3_to_4_4), .ps_in(ps_3_4_to_4_4),
    .ps_out(ps_4_4_to_5_4), .act_out(act_4_4_to_4_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u45 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_4_4_to_4_5), .ps_in(ps_3_5_to_4_5),
    .ps_out(ps_4_5_to_5_5), .act_out(act_4_5_to_4_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u46 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_4_5_to_4_6), .ps_in(ps_3_6_to_4_6),
    .ps_out(ps_4_6_to_5_6), .act_out(act_4_6_to_4_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u47 (
    .clk(clk), .rst(rst), .load_w(load_w_r4), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_4_6_to_4_7), .ps_in(ps_3_7_to_4_7),
    .ps_out(ps_4_7_to_5_7), .act_out(), .overflow_flag());

  // Row 5 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u50 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_5), .ps_in(ps_4_0_to_5_0),
    .ps_out(ps_5_0_to_6_0), .act_out(act_5_0_to_5_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u51 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_5_0_to_5_1), .ps_in(ps_4_1_to_5_1),
    .ps_out(ps_5_1_to_6_1), .act_out(act_5_1_to_5_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u52 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_5_1_to_5_2), .ps_in(ps_4_2_to_5_2),
    .ps_out(ps_5_2_to_6_2), .act_out(act_5_2_to_5_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u53 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_5_2_to_5_3), .ps_in(ps_4_3_to_5_3),
    .ps_out(ps_5_3_to_6_3), .act_out(act_5_3_to_5_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u54 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_5_3_to_5_4), .ps_in(ps_4_4_to_5_4),
    .ps_out(ps_5_4_to_6_4), .act_out(act_5_4_to_5_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u55 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_5_4_to_5_5), .ps_in(ps_4_5_to_5_5),
    .ps_out(ps_5_5_to_6_5), .act_out(act_5_5_to_5_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u56 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_5_5_to_5_6), .ps_in(ps_4_6_to_5_6),
    .ps_out(ps_5_6_to_6_6), .act_out(act_5_6_to_5_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u57 (
    .clk(clk), .rst(rst), .load_w(load_w_r5), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_5_6_to_5_7), .ps_in(ps_4_7_to_5_7),
    .ps_out(ps_5_7_to_6_7), .act_out(), .overflow_flag());

  // Row 6 (8 PEs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u60 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_6), .ps_in(ps_5_0_to_6_0),
    .ps_out(ps_6_0_to_7_0), .act_out(act_6_0_to_6_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u61 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_6_0_to_6_1), .ps_in(ps_5_1_to_6_1),
    .ps_out(ps_6_1_to_7_1), .act_out(act_6_1_to_6_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u62 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_6_1_to_6_2), .ps_in(ps_5_2_to_6_2),
    .ps_out(ps_6_2_to_7_2), .act_out(act_6_2_to_6_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u63 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_6_2_to_6_3), .ps_in(ps_5_3_to_6_3),
    .ps_out(ps_6_3_to_7_3), .act_out(act_6_3_to_6_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u64 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_6_3_to_6_4), .ps_in(ps_5_4_to_6_4),
    .ps_out(ps_6_4_to_7_4), .act_out(act_6_4_to_6_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u65 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_6_4_to_6_5), .ps_in(ps_5_5_to_6_5),
    .ps_out(ps_6_5_to_7_5), .act_out(act_6_5_to_6_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u66 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_6_5_to_6_6), .ps_in(ps_5_6_to_6_6),
    .ps_out(ps_6_6_to_7_6), .act_out(act_6_6_to_6_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u67 (
    .clk(clk), .rst(rst), .load_w(load_w_r6), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_6_6_to_6_7), .ps_in(ps_5_7_to_6_7),
    .ps_out(ps_6_7_to_7_7), .act_out(), .overflow_flag());

  // Row 7 (bottom - 8 PEs with outputs)
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u70 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_0), .act_in(act_l_7), .ps_in(ps_6_0_to_7_0),
    .ps_out(c_out_70), .act_out(act_7_0_to_7_1), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u71 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_1), .act_in(act_7_0_to_7_1), .ps_in(ps_6_1_to_7_1),
    .ps_out(c_out_71), .act_out(act_7_1_to_7_2), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u72 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_2), .act_in(act_7_1_to_7_2), .ps_in(ps_6_2_to_7_2),
    .ps_out(c_out_72), .act_out(act_7_2_to_7_3), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u73 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_3), .act_in(act_7_2_to_7_3), .ps_in(ps_6_3_to_7_3),
    .ps_out(c_out_73), .act_out(act_7_3_to_7_4), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u74 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_4), .act_in(act_7_3_to_7_4), .ps_in(ps_6_4_to_7_4),
    .ps_out(c_out_74), .act_out(act_7_4_to_7_5), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u75 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_5), .act_in(act_7_4_to_7_5), .ps_in(ps_6_5_to_7_5),
    .ps_out(c_out_75), .act_out(act_7_5_to_7_6), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u76 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_6), .act_in(act_7_5_to_7_6), .ps_in(ps_6_6_to_7_6),
    .ps_out(c_out_76), .act_out(act_7_6_to_7_7), .overflow_flag());
  pe #(.W_BITS(W_BITS), .ACC_BITS(ACC_BITS), .PIPELINE_MUL(PIPELINE_MUL), .ENABLE_OVFCHK(0)) u77 (
    .clk(clk), .rst(rst), .load_w(load_w_r7), .clear_ps(clear_ps), .mac_en(mac_en),
    .w_in(w_col_7), .act_in(act_7_6_to_7_7), .ps_in(ps_6_7_to_7_7),
    .ps_out(c_out_77), .act_out(), .overflow_flag());

endmodule