// =============================================================
// Processing Element (PE) for Weight-Stationary Systolic Array
// Verilog-2005 Compatible
// =============================================================
module pe #(
    parameter W_BITS        = 8,    // Activation/weight precision
    parameter ACC_BITS      = 32,   // Accumulator width
    parameter PIPELINE_MUL  = 0,    // 0: comb multiplier, 1: 1-cycle pipelined multiplier
    parameter ENABLE_OVFCHK = 0     // 1: enable overflow flag output
)(
    input                       clk,
    input                       rst,       // synchronous, active-high

    // Control
    input                       load_w,    // latch new weight
    input                       clear_ps,  // clear partial sum
    input                       mac_en,    // perform MAC

    // Data
    input signed   [W_BITS-1:0] w_in,
    input signed   [W_BITS-1:0] act_in,
    input signed   [ACC_BITS-1:0] ps_in,

    output reg signed [ACC_BITS-1:0] ps_out,
    output reg signed [W_BITS-1:0]   act_out,

    // Optional overflow indicator
    output reg                     overflow_flag
);

    // ---------------------------------------------------------
    // Width and safety parameters
    // ---------------------------------------------------------
    localparam PROD_BITS = 2 * W_BITS;

    // Stationary weight register
    reg signed [W_BITS-1:0] w_reg;

    // Multiplier
    reg  signed [PROD_BITS-1:0] product_r;
    wire signed [PROD_BITS-1:0] product_s;

    // Combinational multiply or pipelined multiply
    generate
        if (PIPELINE_MUL) begin : gen_pipe_mult
            always @(posedge clk) begin
                if (rst)
                    product_r <= {PROD_BITS{1'b0}};
                else
                    product_r <= act_in * w_reg;
            end
            assign product_s = product_r;
        end else begin : gen_comb_mult
            assign product_s = act_in * w_reg;
        end
    endgenerate

    // Sign extension to accumulator width
    wire signed [ACC_BITS-1:0] product_ext;
    assign product_ext = {{(ACC_BITS - PROD_BITS){product_s[PROD_BITS-1]}}, product_s};

    // Overflow detection
    wire signed [ACC_BITS:0] sum_wide;
    assign sum_wide = ps_in + product_ext;
    wire overflow_detected;
    assign overflow_detected = (sum_wide[ACC_BITS] != sum_wide[ACC_BITS-1]);

    // ---------------------------------------------------------
    // Sequential behavior
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            w_reg         <= {W_BITS{1'b0}};
            ps_out        <= {ACC_BITS{1'b0}};
            act_out       <= {W_BITS{1'b0}};
            overflow_flag <= 1'b0;
        end else begin
            // Load stationary weight
            if (load_w)
                w_reg <= w_in;

            // Always-forward activations
            act_out <= act_in;

            // Partial-sum priority: clear_ps > mac_en > forward
            if (clear_ps) begin
                ps_out <= {ACC_BITS{1'b0}};
            end else if (mac_en) begin
                ps_out <= ps_in + product_ext;
            end else begin
                ps_out <= ps_in;
            end

            // Overflow flag handling
            if (!ENABLE_OVFCHK) begin
                overflow_flag <= 1'b0;
            end else if (clear_ps) begin
                overflow_flag <= 1'b0;
            end else if (mac_en) begin
                overflow_flag <= overflow_detected;
            end
        end
    end

endmodule
