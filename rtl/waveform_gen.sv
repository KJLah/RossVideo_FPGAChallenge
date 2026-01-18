module waveform_gen (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  x,
    input  logic [9:0]  y,
    output logic        draw,
    output logic [7:0]  ecg_sample
);

    (* ram_init_file = "ecg_data.mem" *) reg [7:0] ecg_mem [0:255];
    initial begin
        $readmemh("rtl/ecg_data.mem", ecg_mem);
    end

    reg [7:0] index;

    always_ff @(posedge clk) begin
        if (reset)
            index <= 0;
        else if (x == 639)
            index <= index + 1;
    end

    assign ecg_sample = ecg_mem[index];

    // map 0–255 → 0–479 (with margin to avoid edge overflow)
    wire [9:0] ecg_y;
    assign ecg_y = 10'd40 + (10'd400 - ((ecg_sample * 10'd400) >> 8));

    // Draw 3-pixel thick line with bounds checking to prevent underflow
    assign draw = (x < 640) && (y < 480) &&
                  ((y == ecg_y) || 
                   (y == ecg_y + 1) || 
                   ((ecg_y > 0) && (y == ecg_y - 1)));

endmodule
