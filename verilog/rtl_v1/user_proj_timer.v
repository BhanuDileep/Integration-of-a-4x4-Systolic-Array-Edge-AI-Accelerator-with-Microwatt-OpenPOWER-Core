`default_nettype none

// =============================================================
// User Project Timer - Replaced with Simplified Systolic Array
// Matches OpenFrame GPIO-based template
// =============================================================

module user_proj_timer (
`ifdef USE_POWER_PINS
    inout vccd1,    // User area 1 1.8V supply
    inout vssd1,    // User area 1 digital ground
`endif

    // Clock and Reset (from GPIO)
    input wb_clk_i,
    input wb_rst_i,

    // IOs (11 pins available)
    input  [10:0] io_in,
    output [10:0] io_out,
    output [10:0] io_oeb
);

    // ================================================================
    // GPIO Pin Assignment (11 pins total)
    // ================================================================
    // Inputs (2 pins):
    wire start = io_in[0];      // Start computation
    wire clear = io_in[1];      // Clear results
    // io_in[10:2] - unused (available for future use)
    
    // Outputs (11 pins):
    // io_out[0] - done flag
    // io_out[1] - busy flag  
    // io_out[10:2] - result data (9 bits = can show partial result)
    
    // ================================================================
    // Simple Control FSM
    // ================================================================
    reg [2:0] state;
    reg [2:0] cycle_count;
    wire start_pulse, clear_pulse;
    reg start_q, clear_q;
    
    localparam IDLE   = 3'd0;
    localparam LOAD   = 3'd1;
    localparam CLEAR  = 3'd2;
    localparam COMPUTE = 3'd3;
    localparam DONE   = 3'd4;
    
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            state <= IDLE;
            cycle_count <= 0;
            start_q <= 0;
            clear_q <= 0;
        end else begin
            start_q <= start;
            clear_q <= clear;
            
            case (state)
                IDLE: begin
                    cycle_count <= 0;
                    if (start && !start_q)
                        state <= LOAD;
                    else if (clear && !clear_q)
                        state <= CLEAR;
                end
                
                LOAD: begin
                    if (cycle_count == 3) begin
                        state <= CLEAR;
                        cycle_count <= 0;
                    end else
                        cycle_count <= cycle_count + 1;
                end
                
                CLEAR: begin
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (cycle_count == 3) begin
                        state <= DONE;
                        cycle_count <= 0;
                    end else
                        cycle_count <= cycle_count + 1;
                end
                
                DONE: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign start_pulse = (state == LOAD);
    assign clear_pulse = (state == CLEAR);
    
    // ================================================================
    // Hardcoded Test Matrices (for demonstration)
    // A = [1,2,3,4; 5,6,7,8; 9,1,2,3; 4,5,6,7]
    // B = [1,0,1,2; 2,1,3,1; 1,2,0,1; 3,2,1,0]
    // Expected C[3][0] = 41
    // ================================================================
    
    reg signed [7:0] a_row_0, a_row_1, a_row_2, a_row_3;
    reg signed [7:0] w_col_0, w_col_1, w_col_2, w_col_3;
    wire signed [31:0] c_out_30, c_out_31, c_out_32, c_out_33;
    
    // Weight loading (B transposed)
    always @(posedge wb_clk_i) begin
        if (state == LOAD) begin
            case (cycle_count)
                3'd0: begin w_col_0 <= 8'd1; w_col_1 <= 8'd2; w_col_2 <= 8'd1; w_col_3 <= 8'd3; end
                3'd1: begin w_col_0 <= 8'd0; w_col_1 <= 8'd1; w_col_2 <= 8'd2; w_col_3 <= 8'd2; end
                3'd2: begin w_col_0 <= 8'd1; w_col_1 <= 8'd3; w_col_2 <= 8'd0; w_col_3 <= 8'd1; end
                3'd3: begin w_col_0 <= 8'd2; w_col_1 <= 8'd1; w_col_2 <= 8'd1; w_col_3 <= 8'd0; end
            endcase
        end
    end
    
    // Activation streaming (A rows)
    always @(posedge wb_clk_i) begin
        if (state == COMPUTE) begin
            case (cycle_count)
                3'd0: begin a_row_0 <= 8'd1; a_row_1 <= 8'd5; a_row_2 <= 8'd9; a_row_3 <= 8'd4; end
                3'd1: begin a_row_0 <= 8'd2; a_row_1 <= 8'd6; a_row_2 <= 8'd1; a_row_3 <= 8'd5; end
                3'd2: begin a_row_0 <= 8'd3; a_row_1 <= 8'd7; a_row_2 <= 8'd2; a_row_3 <= 8'd6; end
                3'd3: begin a_row_0 <= 8'd4; a_row_1 <= 8'd8; a_row_2 <= 8'd3; a_row_3 <= 8'd7; end
            endcase
        end else begin
            a_row_0 <= 0; a_row_1 <= 0; a_row_2 <= 0; a_row_3 <= 0;
        end
    end
    
    // ================================================================
    // Systolic Array Instantiation
    // ================================================================
    wire mac_enable = (state == COMPUTE);
    wire load_enable = (state == LOAD);
    
    systolic_array_4x4 #(
        .W_BITS(8),
        .ACC_BITS(32),
        .PIPELINE_MUL(0)
    ) u_array (
        .clk(wb_clk_i),
        .rst(wb_rst_i),
        .start(start_pulse),
        .clear_ps(clear_pulse),
        .mac_en(mac_enable),
        .load_w(load_enable),
        .load_row_en(4'b1111),
        .a_row_0(a_row_0), .a_row_1(a_row_1),
        .a_row_2(a_row_2), .a_row_3(a_row_3),
        .w_col_0(w_col_0), .w_col_1(w_col_1),
        .w_col_2(w_col_2), .w_col_3(w_col_3),
        .busy(),
        .done(),
        .c_out_30(c_out_30), .c_out_31(c_out_31),
        .c_out_32(c_out_32), .c_out_33(c_out_33)
    );
    
    // ================================================================
    // Output Preview (show result selector)
    // Use 9 bits to show different results based on state
    // ================================================================
    reg [8:0] result_data;
    wire done, busy;
    
    always @(*) begin
        if (done) begin
            // Show C[3][0] lower 9 bits when done (expected: 41 = 0x29)
            result_data = c_out_30[8:0];
        end else if (busy) begin
            // Show cycle count during computation
            result_data = {6'd0, cycle_count};
        end else begin
            // Idle - show fixed pattern
            result_data = 9'h155;  // Alternating pattern for debug
        end
    end
    
    assign done = (state == DONE);
    assign busy = (state != IDLE) && (state != DONE);
    
    // ================================================================
    // GPIO Output Mapping (11 pins)
    // ================================================================
    assign io_out = {result_data[8:0], busy, done};
    assign io_oeb = 11'd0;  // All outputs

endmodule

`default_nettype wire
