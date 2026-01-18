/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack-a-Thon 2026
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (       
    .clk_i          ( ),//               
    .cen_i          ( ),// video clock enable
    .rst_i          ( ),//
    .vid_sel_i      ( ),//
    .vid_rgb_i      ( ),//[23:0] = R[23:16], G[15:8], B[7:0]
    .vh_blank_i     ( ),//[ 1:0] = {Vblank, Hblank}
    .dvh_sync_i     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }
    // Output signals
    .dvh_sync_o     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }  delayed
    .vid_rgb_o      ( ) //[23:0] = R[23:16], G[15:8], B[7:0] delayed
);

-------------------------------------------------------------------------- */


module video_uut (
    input  wire         clk_i           ,// clock
    input  wire         cen_i           ,// clock enable
    input  wire         rst_i           ,// reset
    input  wire         vid_sel_i       ,// select between video sources
    input  wire [23:0]  vid_rgb_i       ,// [23:0] = R[23:16], G[15:8], B[7:0]
    input  wire [1:0]   vh_blank_i      ,// input  video timing signals
    input  wire [2:0]   dvh_sync_i      ,// HDMI timing signals
    output wire [2:0]   dvh_sync_o      ,// HDMI timing signals delayed
    output wire [23:0]  vid_rgb_o        // [23:0] = R[23:16], G[15:8], B[7:0]
); 

// Delayed signals for edge detection
reg HD, VD;  // Horizontal Delay, Vertical Delay
wire HR, HF, VR, VF;  // Horizontal Rising/Falling, Vertical Rising/Falling

// Counters
reg [11:0] HCNT;  // Horizontal counter: 0-1920
reg [10:0] VCNT;  // Vertical counter: 0-1024 (actually 0-1079 for 1080p)

// Edge detection
assign HR = ~HD && vh_blank_i[0];  // Horizontal Rising edge (entering blank)
assign HF = HD && ~vh_blank_i[0];  // Horizontal Falling edge (leaving blank)
assign VR = ~VD && vh_blank_i[1];  // Vertical Rising edge (entering blank)
assign VF = VD && ~vh_blank_i[1];  // Vertical Falling edge (leaving blank)

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

always @(posedge clk_i) begin
    if (rst_i) begin
        HD <= 1'b0;
        VD <= 1'b0;
        HCNT <= 12'd0;
        VCNT <= 11'd0;
        vid_rgb_d1 <= 24'h00_00_00;
        dvh_sync_d1 <= 3'b000;
    end else if(cen_i) begin
        // Update delayed signals
        HD <= vh_blank_i[0];  // Horizontal blank delay
        VD <= vh_blank_i[1];  // Vertical blank delay
        
        // Horizontal counter: 0-1920
        // Reset on HF (falling edge = leaving blank = start of visible line)
        // Increment only when not blanking
        if (HF) begin  // Horizontal falling edge (leaving blank = start of visible line)
            HCNT <= 12'd0;
        end else if (!vh_blank_i[0]) begin  // Not blanking - increment
            HCNT <= HCNT + 1;
        end
        
        // Vertical counter: 0-1079 (for 1080p)
        // Reset on VF (falling edge = leaving blank = start of frame)
        // Increment on HR (rising edge = entering blank = end of line)
        if (VF) begin  // Vertical falling edge (leaving blank = start of frame)
            VCNT <= 11'd0;
        end else if (HR) begin  // Horizontal rising edge (entering blank = end of line)
            VCNT <= VCNT + 1;
        end
        
        // Draw static 50x50 square in top right
        // Top right: X from 1870 to 1920 (1920-50=1870), Y from 0 to 50
        if ((HCNT >= 12'd1870 && HCNT < 12'd1920) &&
            (VCNT >= 11'd0 && VCNT < 11'd50)) begin
            vid_rgb_d1 <= 24'hFF_FF_FF;  // White square
        end else begin
            vid_rgb_d1 <= 24'h00_00_00;  // Black background
        end
        
        dvh_sync_d1 <= dvh_sync_i;
    end
end

// OUTPUT
assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule

