module fpga_top (
    input  logic clk,       // 27 MHz (Tang Nano 9K) - VGA timing slightly fast
    input  logic reset,
    output logic hsync,
    output logic vsync,
    output logic [2:0] rgb
);

    logic [9:0] x;
    logic [9:0] y;
    logic draw_wave;
    logic [7:0] ecg_sample;
    logic [1:0] mood;

    waveform_gen u_wave (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .draw(draw_wave),
        .ecg_sample(ecg_sample)
    );

    ecg_decoder u_mood (
        .ecg_sample(ecg_sample),
        .mood(mood)
    );

    display_ctrl u_display (
        .clk(clk),
        .reset(reset),
        .draw_wave(draw_wave),
        .mood(mood),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb),
        .x(x),
        .y(y)
    );

endmodule
