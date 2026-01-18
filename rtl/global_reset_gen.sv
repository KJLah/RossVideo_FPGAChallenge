// Global Reset Generator
// Generates a reset pulse on power-up with debouncing

module global_reset_gen #(
    parameter N_BIT_DEBOUNCE = 5,  // N bit shift register debouncer (Min=2)
    parameter N_BIT_COUNT    = 5   // 2^N pulse width counter (Min=2)
) (
    input  wire reset_i,    // Active high asynchronous reset input
    input  wire clk_i,      // External clock oscillator
    output wire reset_o,    // Active high global reset output
    output wire reset_n_o   // Active low global reset output
);

    // Debounce shift register
    reg [N_BIT_DEBOUNCE-1:0] debounce_sr = {N_BIT_DEBOUNCE{1'b1}};
    
    // Power-on reset counter
    reg [N_BIT_COUNT-1:0] reset_cnt = {N_BIT_COUNT{1'b0}};
    reg reset_done = 1'b0;
    
    // Debounced reset
    wire debounced_reset;
    assign debounced_reset = &debounce_sr;  // All 1s = reset active
    
    // Shift register for input debouncing
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            debounce_sr <= {N_BIT_DEBOUNCE{1'b1}};
        end else begin
            debounce_sr <= {debounce_sr[N_BIT_DEBOUNCE-2:0], 1'b0};
        end
    end
    
    // Power-on reset counter
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            reset_cnt  <= {N_BIT_COUNT{1'b0}};
            reset_done <= 1'b0;
        end else if (!reset_done) begin
            if (reset_cnt == {N_BIT_COUNT{1'b1}}) begin
                reset_done <= 1'b1;
            end else begin
                reset_cnt <= reset_cnt + 1'b1;
            end
        end
    end
    
    // Output reset signals
    assign reset_o   = debounced_reset | ~reset_done;
    assign reset_n_o = ~reset_o;

endmodule
