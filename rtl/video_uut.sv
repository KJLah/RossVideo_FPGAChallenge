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

// Animation counter
reg [25:0] frame_counter;
reg [10:0] sprite_x, sprite_y;  // Sprite position (centered)
reg        blink_state;  // For blinking animation

// Sprite size and position (64x64 sprite, centered)
localparam SPRITE_SIZE = 64;
localparam CENTER_X = 960;  // 1920/2
localparam CENTER_Y = 540;  // 1080/2

// Colors
localparam [23:0] COLOR_YELLOW = 24'hFF_FF_00;  // Yellow (Pikachu body)
localparam [23:0] COLOR_RED    = 24'hFF_00_00;  // Red (cheeks)
localparam [23:0] COLOR_BLACK   = 24'h00_00_00;  // Black (eyes, mouth)
localparam [23:0] COLOR_BROWN  = 24'h8B_45_13;  // Brown (ears)
localparam [23:0] COLOR_BG     = 24'h00_00_00;  // Black background

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

// Function to check if pixel is in sprite bounds
wire [10:0] sprite_rel_x, sprite_rel_y;
assign sprite_rel_x = HCNT - sprite_x;
assign sprite_rel_y = VCNT - sprite_y;
wire in_sprite;
assign in_sprite = (HCNT >= sprite_x && HCNT < sprite_x + SPRITE_SIZE &&
                    VCNT >= sprite_y && VCNT < sprite_y + SPRITE_SIZE);

always @(posedge clk_i) begin
    if (rst_i) begin
        HD <= 1'b0;
        VD <= 1'b0;
        HCNT <= 12'd0;
        VCNT <= 11'd0;
        frame_counter <= 26'd0;
        sprite_x <= CENTER_X - SPRITE_SIZE/2;
        sprite_y <= CENTER_Y - SPRITE_SIZE/2;
        blink_state <= 1'b0;
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
            // Update animation once per frame
            frame_counter <= frame_counter + 1;
            
            // Bouncing animation - move sprite up and down
            if (frame_counter[8:0] < 9'd256) begin
                sprite_y <= CENTER_Y - SPRITE_SIZE/2 - (frame_counter[7:0] >> 2);
            end else begin
                sprite_y <= CENTER_Y - SPRITE_SIZE/2 + ((frame_counter[7:0] - 9'd256) >> 2);
            end
            
            // Blinking animation
            blink_state <= (frame_counter[15:12] == 4'hF);
        end else if (HR) begin  // Horizontal rising edge (entering blank = end of line)
            VCNT <= VCNT + 1;
        end
        
        // Draw Pikachu sprite - simplified pixel-by-pixel
        if (in_sprite) begin
            // Default to yellow body
            vid_rgb_d1 <= COLOR_YELLOW;
            
            // Top section - ears (rows 0-8)
            if (sprite_rel_y < 8) begin
                if ((sprite_rel_x >= 20 && sprite_rel_x < 28) || (sprite_rel_x >= 36 && sprite_rel_x < 44)) begin
                    vid_rgb_d1 <= COLOR_BROWN;  // Ears
                end else begin
                    vid_rgb_d1 <= COLOR_BG;  // Background around ears
                end
            end
            // Face section (rows 8-56)
            else if (sprite_rel_y >= 8 && sprite_rel_y < 56) begin
                // Eyes (rows 18-22)
                if (sprite_rel_y >= 18 && sprite_rel_y < 22) begin
                    if (sprite_rel_x >= 18 && sprite_rel_x < 22) begin
                        vid_rgb_d1 <= (blink_state) ? COLOR_YELLOW : COLOR_BLACK;  // Left eye
                    end else if (sprite_rel_x >= 42 && sprite_rel_x < 46) begin
                        vid_rgb_d1 <= (blink_state) ? COLOR_YELLOW : COLOR_BLACK;  // Right eye
                    end
                end
                // Cheeks (rows 24-32)
                else if (sprite_rel_y >= 24 && sprite_rel_y < 32) begin
                    if (sprite_rel_x >= 6 && sprite_rel_x < 14) begin
                        vid_rgb_d1 <= COLOR_RED;  // Left cheek
                    end else if (sprite_rel_x >= 50 && sprite_rel_x < 58) begin
                        vid_rgb_d1 <= COLOR_RED;  // Right cheek
                    end
                end
                // Mouth (rows 36-42)
                else if (sprite_rel_y >= 36 && sprite_rel_y < 42) begin
                    if (sprite_rel_x >= 28 && sprite_rel_x < 36) begin
                        vid_rgb_d1 <= COLOR_BLACK;  // Mouth
                    end
                end
            end
            // Bottom section (rows 56-64)
            else begin
                vid_rgb_d1 <= COLOR_YELLOW;
            end
        end else begin
            vid_rgb_d1 <= COLOR_BG;  // Background
        end
        
        dvh_sync_d1 <= dvh_sync_i;
    end
end

// OUTPUT
assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule
