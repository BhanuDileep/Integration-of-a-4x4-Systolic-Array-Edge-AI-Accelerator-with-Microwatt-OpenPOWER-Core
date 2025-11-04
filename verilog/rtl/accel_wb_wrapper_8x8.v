module accel_wb_wrapper_8x8 #(
  parameter W_BITS       = 8,
  parameter ACC_BITS     = 32,
  parameter SPAD_A_WORDS = 64,
  parameter SPAD_B_WORDS = 64,
  parameter SPAD_C_WORDS = 64,
  parameter PIPELINE_MUL = 0
)(
  input  clk,
  input  rst,

  // Wishbone Slave Interface
  input  [31:0] wbs_adr_i,
  input  [31:0] wbs_dat_i,
  output [31:0] wbs_dat_o,
  input         wbs_we_i,
  input  [3:0]  wbs_sel_i,
  input         wbs_stb_i,
  input         wbs_cyc_i,
  output        wbs_ack_o,

  // Interrupt
  output        irq
);

  // ================================================================
  // Memory-mapped Register Map
  // ================================================================
  localparam [7:0] CTRL    = 8'h00;
  localparam [7:0] STATUS  = 8'h04;
  localparam [7:0] DIM_MNK = 8'h08;
  localparam [7:0] POST_S  = 8'h0C;

  localparam [23:0] A_WIN_BASE = 24'h400000;
  localparam [23:0] B_WIN_BASE = 24'h600000;
  localparam [23:0] C_WIN_BASE = 24'h800000;

  // ================================================================
  // Control / Status Registers
  // ================================================================
  reg        start_req, clear_req, irq_en;
  wire start_pulse;
  reg [9:0]  dim_m, dim_n, dim_k;
  reg [3:0]  post_scale;
  wire status_busy, status_done;

  assign irq = irq_en & status_done;

  wire [31:0] status_word = {30'b0, status_done, status_busy};

  // ================================================================
  // Scratchpads
  // ================================================================
  reg signed [W_BITS-1:0]   spad_a [0:SPAD_A_WORDS-1];
  reg signed [W_BITS-1:0]   spad_b [0:SPAD_B_WORDS-1];
  reg signed [ACC_BITS-1:0] spad_c [0:SPAD_C_WORDS-1];

  // ================================================================
  // Wishbone Interface Logic
  // ================================================================
  wire wb_access = wbs_cyc_i & wbs_stb_i;

  wire [23:0] adr_hi = wbs_adr_i[31:8];
  wire [5:0]  idx    = wbs_adr_i[5:0];  // Only need 6 bits for 64 words

  reg start_req_q, clear_req_q;
  reg [31:0] wbs_dat_o_r;
  reg        wbs_ack_o_r;

  assign wbs_dat_o = wbs_dat_o_r;
  assign wbs_ack_o = wbs_ack_o_r;

  always @(posedge clk) begin
    if (rst) begin
      start_req_q <= 0;
      clear_req_q <= 0;
    end else begin
      start_req_q <= start_req;
      clear_req_q <= clear_req;
    end
  end

  assign start_pulse = start_req & ~start_req_q;

  // Declare loop variables at module level for Verilog-2005
  integer spad_base, spad_kbase;

  always @(posedge clk) begin
    if (rst) begin
      wbs_ack_o_r  <= 0;
      wbs_dat_o_r  <= 0;
      start_req    <= 0;
      clear_req    <= 0;
      irq_en       <= 0;
      dim_m        <= 10'd8;
      dim_n        <= 10'd8;
      dim_k        <= 10'd8;
      post_scale   <= 4'd0;
    end else begin
      wbs_ack_o_r <= 0;

      if (wb_access && !wbs_ack_o_r) begin
        wbs_ack_o_r <= 1;

        // ==================== WRITE ====================
        if (wbs_we_i) begin
          case (wbs_adr_i[7:0])
            CTRL: begin
              if (wbs_sel_i[0]) begin
                start_req <= wbs_dat_i[0];
                clear_req <= wbs_dat_i[1];
                irq_en    <= wbs_dat_i[2];
              end
            end

            DIM_MNK: begin
              if (&wbs_sel_i) begin
                dim_k <= wbs_dat_i[9:0];
                dim_n <= wbs_dat_i[19:10];
                dim_m <= wbs_dat_i[29:20];
              end
            end

            POST_S: begin
              if (wbs_sel_i[0])
                post_scale <= wbs_dat_i[3:0];
            end

            default: begin
              // Scratchpad write windows
              if (adr_hi == A_WIN_BASE && !status_busy) begin
                if (idx < SPAD_A_WORDS && wbs_sel_i[0])
                  spad_a[idx] <= wbs_dat_i[7:0];
              end else if (adr_hi == B_WIN_BASE && !status_busy) begin
                if (idx < SPAD_B_WORDS && wbs_sel_i[0])
                  spad_b[idx] <= wbs_dat_i[7:0];
              end else if (adr_hi == C_WIN_BASE && !status_busy && state == S_IDLE) begin
                if (idx < SPAD_C_WORDS) begin
                  if (wbs_sel_i[0]) spad_c[idx][7:0]   <= wbs_dat_i[7:0];
                  if (wbs_sel_i[1]) spad_c[idx][15:8]  <= wbs_dat_i[15:8];
                  if (wbs_sel_i[2]) spad_c[idx][23:16] <= wbs_dat_i[23:16];
                  if (wbs_sel_i[3]) spad_c[idx][31:24] <= wbs_dat_i[31:24];
                end
              end
            end
          endcase
        end
        // ==================== READ ====================
        else begin
          case (wbs_adr_i[7:0])
            CTRL:    wbs_dat_o_r <= {29'b0, irq_en, clear_req, start_req};
            STATUS:  wbs_dat_o_r <= status_word;
            DIM_MNK: wbs_dat_o_r <= {2'b0, dim_m, dim_n, dim_k};
            POST_S:  wbs_dat_o_r <= {28'b0, post_scale};
            default: begin
              if (adr_hi == A_WIN_BASE && !status_busy)
                wbs_dat_o_r <= (idx < SPAD_A_WORDS) ? {24'b0, spad_a[idx]} : 32'd0;
              else if (adr_hi == B_WIN_BASE && !status_busy)
                wbs_dat_o_r <= (idx < SPAD_B_WORDS) ? {24'b0, spad_b[idx]} : 32'd0;
              else if (adr_hi == C_WIN_BASE)
                wbs_dat_o_r <= (idx < SPAD_C_WORDS) ? spad_c[idx] : 32'd0;
              else
                wbs_dat_o_r <= 32'd0;
            end
          endcase
        end
      end
      
      // Result capture logic - single driver for spad_c
      if (state == S_CAPTURE) begin
        if (0 < SPAD_C_WORDS) spad_c[0] <= c70 >>> post_scale;
        if (1 < SPAD_C_WORDS) spad_c[1] <= c71 >>> post_scale;
        if (2 < SPAD_C_WORDS) spad_c[2] <= c72 >>> post_scale;
        if (3 < SPAD_C_WORDS) spad_c[3] <= c73 >>> post_scale;
        if (4 < SPAD_C_WORDS) spad_c[4] <= c74 >>> post_scale;
        if (5 < SPAD_C_WORDS) spad_c[5] <= c75 >>> post_scale;
        if (6 < SPAD_C_WORDS) spad_c[6] <= c76 >>> post_scale;
        if (7 < SPAD_C_WORDS) spad_c[7] <= c77 >>> post_scale;
      end
    end
  end

  // ================================================================
  // FSM (8 cycles for 8×8)
  // ================================================================
  parameter S_IDLE    = 3'd0;
  parameter S_LOADW   = 3'd1;
  parameter S_CLEAR   = 3'd2;
  parameter S_STREAM  = 3'd3;
  parameter S_DRAIN   = 3'd4;
  parameter S_CAPTURE = 3'd5;

  reg [2:0] state, nstate;
  reg [3:0] loadw_ctr, k_ctr;
  reg [2:0] drain_ctr;
  reg       load_w, mac_en; 
  wire      clear_ps_pulse;

  localparam integer DRAIN_MAX = 7 + (PIPELINE_MUL ? 1 : 0);

  always @(posedge clk) begin
    if (rst) begin
      state      <= S_IDLE;
      loadw_ctr  <= 0;
      k_ctr      <= 0;
      drain_ctr  <= 0;
      load_w     <= 0;
      mac_en     <= 0;
    end else begin
      state <= nstate;
      case (state)
        S_IDLE: begin
          load_w    <= 0;
          mac_en    <= 0;
          loadw_ctr <= 0;
          k_ctr     <= 0;
          drain_ctr <= 0;
        end
        S_LOADW: begin
          load_w <= 1;
          mac_en <= 0;
          if (loadw_ctr != 7)
            loadw_ctr <= loadw_ctr + 4'd1;
        end
        S_CLEAR: begin
          load_w <= 0;
          mac_en <= 0;
        end
        S_STREAM: begin
          load_w <= 0;
          mac_en <= 1;
          if (k_ctr != 7)
            k_ctr <= k_ctr + 4'd1;
        end
        S_DRAIN: begin
          load_w <= 0;
          mac_en <= 0;
          if (drain_ctr != DRAIN_MAX[2:0])
            drain_ctr <= drain_ctr + 3'd1;
        end
        S_CAPTURE: begin
          load_w <= 0;
          mac_en <= 0;
        end
        default: begin
          load_w <= 0;
          mac_en <= 0;
        end
      endcase
    end
  end

  always @(*) begin
    nstate = state;
    case (state)
      S_IDLE:    nstate = start_pulse ? S_LOADW : S_IDLE;
      S_LOADW:   nstate = (loadw_ctr == 7) ? S_CLEAR : S_LOADW;
      S_CLEAR:   nstate = S_STREAM;
      S_STREAM:  nstate = (k_ctr == 7) ? S_DRAIN : S_STREAM;
      S_DRAIN:   nstate = (drain_ctr == DRAIN_MAX[2:0]) ? S_CAPTURE : S_DRAIN;
      S_CAPTURE: nstate = S_IDLE;
      default:   nstate = S_IDLE;
    endcase
  end

  assign status_busy = (state != S_IDLE);
  assign status_done = (state == S_IDLE) && array_done;
  assign clear_ps_pulse = (state == S_CLEAR);

  // ================================================================
  // Scratchpad Read and Drive Inputs (8 rows/cols)
  // ================================================================
  reg signed [W_BITS-1:0] a_row_0, a_row_1, a_row_2, a_row_3;
  reg signed [W_BITS-1:0] a_row_4, a_row_5, a_row_6, a_row_7;
  reg signed [W_BITS-1:0] w_col_0, w_col_1, w_col_2, w_col_3;
  reg signed [W_BITS-1:0] w_col_4, w_col_5, w_col_6, w_col_7;

  always @(posedge clk) begin
    if (rst) begin
      w_col_0 <= 0; w_col_1 <= 0; w_col_2 <= 0; w_col_3 <= 0;
      w_col_4 <= 0; w_col_5 <= 0; w_col_6 <= 0; w_col_7 <= 0;
      a_row_0 <= 0; a_row_1 <= 0; a_row_2 <= 0; a_row_3 <= 0;
      a_row_4 <= 0; a_row_5 <= 0; a_row_6 <= 0; a_row_7 <= 0;
    end else begin
      if (state == S_LOADW) begin
        spad_base <= loadw_ctr * 8;
        w_col_0 <= (spad_base+0 < SPAD_B_WORDS) ? spad_b[spad_base+0] : 0;
        w_col_1 <= (spad_base+1 < SPAD_B_WORDS) ? spad_b[spad_base+1] : 0;
        w_col_2 <= (spad_base+2 < SPAD_B_WORDS) ? spad_b[spad_base+2] : 0;
        w_col_3 <= (spad_base+3 < SPAD_B_WORDS) ? spad_b[spad_base+3] : 0;
        w_col_4 <= (spad_base+4 < SPAD_B_WORDS) ? spad_b[spad_base+4] : 0;
        w_col_5 <= (spad_base+5 < SPAD_B_WORDS) ? spad_b[spad_base+5] : 0;
        w_col_6 <= (spad_base+6 < SPAD_B_WORDS) ? spad_b[spad_base+6] : 0;
        w_col_7 <= (spad_base+7 < SPAD_B_WORDS) ? spad_b[spad_base+7] : 0;
      end
      if (state == S_STREAM) begin
        spad_kbase <= k_ctr;
        a_row_0 <= (0*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[0*8 + spad_kbase] : 0;
        a_row_1 <= (1*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[1*8 + spad_kbase] : 0;
        a_row_2 <= (2*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[2*8 + spad_kbase] : 0;
        a_row_3 <= (3*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[3*8 + spad_kbase] : 0;
        a_row_4 <= (4*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[4*8 + spad_kbase] : 0;
        a_row_5 <= (5*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[5*8 + spad_kbase] : 0;
        a_row_6 <= (6*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[6*8 + spad_kbase] : 0;
        a_row_7 <= (7*8 + spad_kbase < SPAD_A_WORDS) ? spad_a[7*8 + spad_kbase] : 0;
      end
    end
  end

  // ================================================================
  // Systolic Array Instantiation (8×8)
  // ================================================================
  wire array_done;
  wire signed [ACC_BITS-1:0] c70, c71, c72, c73, c74, c75, c76, c77;

  systolic_array_8x8 #(
    .W_BITS(W_BITS),
    .ACC_BITS(ACC_BITS),
    .PIPELINE_MUL(PIPELINE_MUL)
  ) u_array (
    .clk(clk),
    .rst(rst),
    .start(start_pulse),
    .clear_ps(clear_ps_pulse),
    .mac_en(mac_en),
    .load_w(load_w),
    .load_row_en(8'b11111111),
    .a_row_0(a_row_0), .a_row_1(a_row_1), .a_row_2(a_row_2), .a_row_3(a_row_3),
    .a_row_4(a_row_4), .a_row_5(a_row_5), .a_row_6(a_row_6), .a_row_7(a_row_7),
    .w_col_0(w_col_0), .w_col_1(w_col_1), .w_col_2(w_col_2), .w_col_3(w_col_3),
    .w_col_4(w_col_4), .w_col_5(w_col_5), .w_col_6(w_col_6), .w_col_7(w_col_7),
    .busy(),
    .done(array_done),
    .c_out_70(c70), .c_out_71(c71), .c_out_72(c72), .c_out_73(c73),
    .c_out_74(c74), .c_out_75(c75), .c_out_76(c76), .c_out_77(c77)
  );

endmodule