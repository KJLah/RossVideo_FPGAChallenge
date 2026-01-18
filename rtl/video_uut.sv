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

// Snowflake parameters
localparam NUM_SNOWFLAKES = 12;
localparam SNOWFLAKE_SIZE = 16;  // Size of each snowflake

// Snowflake positions and properties
reg [10:0] snowflake_x [0:NUM_SNOWFLAKES-1];  // X positions
reg [10:0] snowflake_y [0:NUM_SNOWFLAKES-1];  // Y positions
reg [7:0]  snowflake_rot [0:NUM_SNOWFLAKES-1];  // Rotation angle (0-255)
reg [3:0]  snowflake_speed [0:NUM_SNOWFLAKES-1];  // Fall speed (1-15)

// Colors
localparam [23:0] COLOR_SNOWFLAKE = 24'hFF_FF_FF;  // White snowflakes
localparam [23:0] COLOR_BG_DARK  = 24'h00_00_20;  // Dark blue background
localparam [23:0] COLOR_BG       = 24'h00_00_40;  // Slightly lighter blue
localparam [23:0] COLOR_MAZE      = 24'h00_40_80;  // Dark blue for maze borders
localparam [23:0] COLOR_LETTER_R      = 24'h00_00_FF;  // BLUE for R (changed from red)
localparam [23:0] COLOR_LETTER_O      = 24'hFF_A5_00;  // ORANGE for O
localparam [23:0] COLOR_LETTER_S1     = 24'hFF_00_00;  // RED for first S
localparam [23:0] COLOR_LETTER_S2     = 24'h00_FF_00;  // GREEN for second S
localparam [23:0] COLOR_GHOST_BLUE   = 24'h00_80_FF;  // Blue ghost
localparam [23:0] COLOR_GHOST_RED    = 24'hFF_00_00;  // Red ghost
localparam [23:0] COLOR_GHOST_PINK   = 24'hFF_B0_FF;  // Pink ghost
localparam [23:0] COLOR_GHOST_GREEN  = 24'h00_FF_00;  // Green ghost
localparam [23:0] COLOR_GHOST_PURPLE = 24'h80_00_FF;  // Purple ghost
localparam [23:0] COLOR_PACMAN    = 24'hFF_FF_00;  // Yellow Pac-Man

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

// Function to draw a simple snowflake pattern
function [23:0] draw_snowflake;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] sx, sy;  // Snowflake center X, Y
    input [7:0]  rot;     // Rotation (not used in simplified version)
    reg [10:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    begin
        // Calculate relative position (absolute value)
        if (px >= sx) begin
            rel_x = px - sx;
            abs_x = px - sx;
        end else begin
            rel_x = sx - px;
            abs_x = sx - px;
        end
        
        if (py >= sy) begin
            rel_y = py - sy;
            abs_y = py - sy;
        end else begin
            rel_y = sy - py;
            abs_y = sy - py;
        end
        
        // Check if pixel is within snowflake bounds
        if (abs_x > SNOWFLAKE_SIZE/2 || abs_y > SNOWFLAKE_SIZE/2) begin
            draw_snowflake = 24'h0;  // Transparent
        end else begin
            // Simple snowflake pattern: center + 4 lines (horizontal, vertical, 2 diagonals)
            // Center dot
            if (abs_x < 2 && abs_y < 2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Horizontal line
            else if (abs_y < 2 && abs_x < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Vertical line
            else if (abs_x < 2 && abs_y < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Diagonal 1: check if on line y = x (within tolerance)
            else if (abs_x == abs_y && abs_x < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Diagonal 2: check if on line y = -x (within tolerance) - simplified
            else if ((abs_x + abs_y < 3) && (abs_x > 1 || abs_y > 1)) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            else begin
                draw_snowflake = 24'h0;  // Transparent
            end
        end
    end
endfunction

// Check if any snowflake is at this pixel
wire [23:0] snowflake_color [0:NUM_SNOWFLAKES-1];
genvar i;
generate
    for (i = 0; i < NUM_SNOWFLAKES; i = i + 1) begin : gen_snowflakes
        assign snowflake_color[i] = draw_snowflake(HCNT, VCNT, snowflake_x[i], snowflake_y[i], snowflake_rot[i]);
    end
endgenerate

// Function to draw maze walls and letters (static Pac-Man style)
function [23:0] draw_maze;
    input [10:0] px, py;  // Pixel coordinates
    input signed [10:0] offset_y;  // Not used (kept for compatibility)
    reg [10:0] center_x, center_y;
    reg [10:0] letter_start_x;
    reg [10:0] letter_width, letter_height;
    reg [10:0] thickness_outer, thickness_inner, thickness_gap;
    reg [10:0] border_thickness;
    reg [10:0] corner_size;
    begin
        center_x = 960;  // Screen center X
        center_y = 540;  // Screen center Y
        draw_maze = 24'h0;  // Transparent by default
        
        border_thickness = 15;  // Double-line border thickness
        corner_size = 30;  // Size of corner rounding
        
        // Draw double-lined Pac-Man style borders with rounded corners
        // OUTER border lines
        // Top outer border
        if (py < border_thickness && px >= corner_size && px < 1920 - corner_size) begin
            draw_maze = COLOR_MAZE;
        end
        // Bottom outer border
        if (py >= 1080 - border_thickness && px >= corner_size && px < 1920 - corner_size) begin
            draw_maze = COLOR_MAZE;
        end
        // Left outer border
        if (px < border_thickness && py >= corner_size && py < 1080 - corner_size) begin
            draw_maze = COLOR_MAZE;
        end
        // Right outer border
        if (px >= 1920 - border_thickness && py >= corner_size && py < 1080 - corner_size) begin
            draw_maze = COLOR_MAZE;
        end
        
        // INNER border lines (double-line effect)
        // Top inner border
        if (py >= border_thickness + 10 && py < border_thickness + 15 && px >= corner_size + 10 && px < 1920 - corner_size - 10) begin
            draw_maze = COLOR_MAZE;
        end
        // Bottom inner border
        if (py >= 1080 - border_thickness - 15 && py < 1080 - border_thickness - 10 && px >= corner_size + 10 && px < 1920 - corner_size - 10) begin
            draw_maze = COLOR_MAZE;
        end
        // Left inner border
        if (px >= border_thickness + 10 && px < border_thickness + 15 && py >= corner_size + 10 && py < 1080 - corner_size - 10) begin
            draw_maze = COLOR_MAZE;
        end
        // Right inner border
        if (px >= 1920 - border_thickness - 15 && px < 1920 - border_thickness - 10 && py >= corner_size + 10 && py < 1080 - corner_size - 10) begin
            draw_maze = COLOR_MAZE;
        end
        
        // Corner pieces (simple L-shaped corners)
        // Top-left corner
        if ((px < corner_size && py < border_thickness) || (px < border_thickness && py < corner_size)) begin
            draw_maze = COLOR_MAZE;
        end
        if ((px >= border_thickness + 10 && px < corner_size + 10 && py >= border_thickness + 10 && py < border_thickness + 15) ||
            (px >= border_thickness + 10 && px < border_thickness + 15 && py >= border_thickness + 10 && py < corner_size + 10)) begin
            draw_maze = COLOR_MAZE;
        end
        // Top-right corner
        if ((px >= 1920 - corner_size && py < border_thickness) || (px >= 1920 - border_thickness && py < corner_size)) begin
            draw_maze = COLOR_MAZE;
        end
        if ((px >= 1920 - corner_size - 10 && px < 1920 - border_thickness - 10 && py >= border_thickness + 10 && py < border_thickness + 15) ||
            (px >= 1920 - border_thickness - 15 && px < 1920 - border_thickness - 10 && py >= border_thickness + 10 && py < corner_size + 10)) begin
            draw_maze = COLOR_MAZE;
        end
        // Bottom-left corner
        if ((px < corner_size && py >= 1080 - border_thickness) || (px < border_thickness && py >= 1080 - corner_size)) begin
            draw_maze = COLOR_MAZE;
        end
        if ((px >= border_thickness + 10 && px < corner_size + 10 && py >= 1080 - border_thickness - 15 && py < 1080 - border_thickness - 10) ||
            (px >= border_thickness + 10 && px < border_thickness + 15 && py >= 1080 - corner_size - 10 && py < 1080 - border_thickness - 10)) begin
            draw_maze = COLOR_MAZE;
        end
        // Bottom-right corner
        if ((px >= 1920 - corner_size && py >= 1080 - border_thickness) || (px >= 1920 - border_thickness && py >= 1080 - corner_size)) begin
            draw_maze = COLOR_MAZE;
        end
        if ((px >= 1920 - corner_size - 10 && px < 1920 - border_thickness - 10 && py >= 1080 - border_thickness - 15 && py < 1080 - border_thickness - 10) ||
            (px >= 1920 - border_thickness - 15 && px < 1920 - border_thickness - 10 && py >= 1080 - corner_size - 10 && py < 1080 - border_thickness - 10)) begin
            draw_maze = COLOR_MAZE;
        end
        
        // HUGE ROSS letters - Pac-Man style double-lined maze paths with hollow space
        letter_start_x = 200;  // Start from left side
        letter_width = 350;  // Much wider letters
        letter_height = 450;  // Much taller letters
        thickness_outer = 16;  // Outer wall thickness
        thickness_inner = 16;   // Inner wall thickness
        thickness_gap = 20;     // Gap between outer and inner walls (hollow space)
        
        // R - First letter (BLUE) - Double-lined Pac-Man style R
        if (px >= letter_start_x && px < letter_start_x + letter_width && py >= center_y - letter_height/2 && py < center_y + letter_height/2) begin
            // Left vertical wall (full height) - double-lined path
            if (((px >= letter_start_x && px < letter_start_x + thickness_outer) ||  
                 (px >= letter_start_x + thickness_outer + thickness_gap && px < letter_start_x + thickness_outer + thickness_gap + thickness_inner)) &&
                (py >= center_y - letter_height/2 && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_R;
            end
            // Top horizontal wall - double-lined path
            if (((py >= center_y - letter_height/2 && py < center_y - letter_height/2 + thickness_outer) ||  
                 (py >= center_y - letter_height/2 + thickness_outer + thickness_gap && py < center_y - letter_height/2 + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x && px < letter_start_x + letter_width)) begin
                draw_maze = COLOR_LETTER_R;
            end
            // Top-right vertical (to middle) - double-lined path
            if (((px >= letter_start_x + letter_width - thickness_outer && px < letter_start_x + letter_width) ||  
                 (px >= letter_start_x + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y - letter_height/2 + thickness_outer && py < center_y)) begin
                draw_maze = COLOR_LETTER_R;
            end
            // Middle horizontal wall - double-lined path
            if (((py >= center_y && py < center_y + thickness_outer) ||  
                 (py >= center_y + thickness_outer + thickness_gap && py < center_y + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x && px < letter_start_x + letter_width)) begin
                draw_maze = COLOR_LETTER_R;
            end
            // Bottom-right diagonal leg - double-lined path (simplified as vertical)
            if (((px >= letter_start_x + letter_width - thickness_outer && px < letter_start_x + letter_width) ||  
                 (px >= letter_start_x + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y + thickness_outer && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_R;
            end
        end
        
        // O - Second letter (ORANGE) - Double-lined Pac-Man style O (rectangular loop)
        if (px >= letter_start_x + 430 && px < letter_start_x + 430 + letter_width && py >= center_y - letter_height/2 && py < center_y + letter_height/2) begin
            // Left vertical wall - double-lined path
            if (((px >= letter_start_x + 430 && px < letter_start_x + 430 + thickness_outer) ||  
                 (px >= letter_start_x + 430 + thickness_outer + thickness_gap && px < letter_start_x + 430 + thickness_outer + thickness_gap + thickness_inner)) &&
                (py >= center_y - letter_height/2 && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_O;
            end
            // Right vertical wall - double-lined path
            if (((px >= letter_start_x + 430 + letter_width - thickness_outer && px < letter_start_x + 430 + letter_width) ||  
                 (px >= letter_start_x + 430 + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + 430 + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y - letter_height/2 && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_O;
            end
            // Top horizontal wall - double-lined path
            if (((py >= center_y - letter_height/2 && py < center_y - letter_height/2 + thickness_outer) ||  
                 (py >= center_y - letter_height/2 + thickness_outer + thickness_gap && py < center_y - letter_height/2 + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x + 430 + thickness_outer && px < letter_start_x + 430 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_O;
            end
            // Bottom horizontal wall - double-lined path
            if (((py >= center_y + letter_height/2 - thickness_outer && py < center_y + letter_height/2) ||  
                 (py >= center_y + letter_height/2 - thickness_outer - thickness_gap - thickness_inner && py < center_y + letter_height/2 - thickness_outer - thickness_gap)) &&
                (px >= letter_start_x + 430 + thickness_outer && px < letter_start_x + 430 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_O;
            end
        end
        
        // S - Third letter (RED) - Double-lined Pac-Man style S
        if (px >= letter_start_x + 860 && px < letter_start_x + 860 + letter_width && py >= center_y - letter_height/2 && py < center_y + letter_height/2) begin
            // Top LEFT vertical (top half only) - double-lined path
            if (((px >= letter_start_x + 860 && px < letter_start_x + 860 + thickness_outer) ||  
                 (px >= letter_start_x + 860 + thickness_outer + thickness_gap && px < letter_start_x + 860 + thickness_outer + thickness_gap + thickness_inner)) &&
                (py >= center_y - letter_height/2 + thickness_outer && py < center_y)) begin
                draw_maze = COLOR_LETTER_S1;
            end
            // Top horizontal wall - double-lined path
            if (((py >= center_y - letter_height/2 && py < center_y - letter_height/2 + thickness_outer) ||  
                 (py >= center_y - letter_height/2 + thickness_outer + thickness_gap && py < center_y - letter_height/2 + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x + 860 + thickness_outer && px < letter_start_x + 860 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_S1;
            end
            // Top right vertical stub - double-lined path
            if (((px >= letter_start_x + 860 + letter_width - thickness_outer && px < letter_start_x + 860 + letter_width) ||  
                 (px >= letter_start_x + 860 + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + 860 + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y - letter_height/2 + thickness_outer && py < center_y - letter_height/2 + 60)) begin
                draw_maze = COLOR_LETTER_S1;
            end
            // Middle horizontal wall - double-lined path
            if (((py >= center_y && py < center_y + thickness_outer) ||  
                 (py >= center_y + thickness_outer + thickness_gap && py < center_y + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x + 860 && px < letter_start_x + 860 + letter_width)) begin
                draw_maze = COLOR_LETTER_S1;
            end
            // Bottom RIGHT vertical (bottom half) - double-lined path
            if (((px >= letter_start_x + 860 + letter_width - thickness_outer && px < letter_start_x + 860 + letter_width) ||  
                 (px >= letter_start_x + 860 + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + 860 + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y + thickness_outer && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_S1;
            end
            // Bottom horizontal wall - double-lined path
            if (((py >= center_y + letter_height/2 - thickness_outer && py < center_y + letter_height/2) ||  
                 (py >= center_y + letter_height/2 - thickness_outer - thickness_gap - thickness_inner && py < center_y + letter_height/2 - thickness_outer - thickness_gap)) &&
                (px >= letter_start_x + 860 && px < letter_start_x + 860 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_S1;
            end
        end
        
        // S - Fourth letter (GREEN) - Double-lined Pac-Man style S (same as third)
        if (px >= letter_start_x + 1290 && px < letter_start_x + 1290 + letter_width && py >= center_y - letter_height/2 && py < center_y + letter_height/2) begin
            // Top LEFT vertical (top half only) - double-lined path
            if (((px >= letter_start_x + 1290 && px < letter_start_x + 1290 + thickness_outer) ||  
                 (px >= letter_start_x + 1290 + thickness_outer + thickness_gap && px < letter_start_x + 1290 + thickness_outer + thickness_gap + thickness_inner)) &&
                (py >= center_y - letter_height/2 + thickness_outer && py < center_y)) begin
                draw_maze = COLOR_LETTER_S2;
            end
            // Top horizontal wall - double-lined path
            if (((py >= center_y - letter_height/2 && py < center_y - letter_height/2 + thickness_outer) ||  
                 (py >= center_y - letter_height/2 + thickness_outer + thickness_gap && py < center_y - letter_height/2 + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x + 1290 + thickness_outer && px < letter_start_x + 1290 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_S2;
            end
            // Top right vertical stub - double-lined path
            if (((px >= letter_start_x + 1290 + letter_width - thickness_outer && px < letter_start_x + 1290 + letter_width) ||  
                 (px >= letter_start_x + 1290 + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + 1290 + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y - letter_height/2 + thickness_outer && py < center_y - letter_height/2 + 60)) begin
                draw_maze = COLOR_LETTER_S2;
            end
            // Middle horizontal wall - double-lined path
            if (((py >= center_y && py < center_y + thickness_outer) ||  
                 (py >= center_y + thickness_outer + thickness_gap && py < center_y + thickness_outer + thickness_gap + thickness_inner)) &&
                (px >= letter_start_x + 1290 && px < letter_start_x + 1290 + letter_width)) begin
                draw_maze = COLOR_LETTER_S2;
            end
            // Bottom RIGHT vertical (bottom half) - double-lined path
            if (((px >= letter_start_x + 1290 + letter_width - thickness_outer && px < letter_start_x + 1290 + letter_width) ||  
                 (px >= letter_start_x + 1290 + letter_width - thickness_outer - thickness_gap - thickness_inner && px < letter_start_x + 1290 + letter_width - thickness_outer - thickness_gap)) &&
                (py >= center_y + thickness_outer && py < center_y + letter_height/2)) begin
                draw_maze = COLOR_LETTER_S2;
            end
            // Bottom horizontal wall - double-lined path
            if (((py >= center_y + letter_height/2 - thickness_outer && py < center_y + letter_height/2) ||  
                 (py >= center_y + letter_height/2 - thickness_outer - thickness_gap - thickness_inner && py < center_y + letter_height/2 - thickness_outer - thickness_gap)) &&
                (px >= letter_start_x + 1290 && px < letter_start_x + 1290 + letter_width - thickness_outer)) begin
                draw_maze = COLOR_LETTER_S2;
            end
        end
    end
endfunction

// Function to draw Pac-Man (bigger, circle with triangle mouth - ANIMATED)
function [23:0] draw_pacman;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] pac_x, pac_y;  // Pac-Man center X, Y
    input [7:0]  mouth_angle;  // Mouth opening angle (0-63, used to scale mouth)
    reg signed [11:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    reg [13:0] dist_sq;
    reg signed [11:0] mouth_slope;  // Mouth slope based on angle
    begin
        rel_x = px - pac_x;
        rel_y = py - pac_y;
        
        if (rel_x >= 0) begin
            abs_x = rel_x;
        end else begin
            abs_x = -rel_x;
        end
        
        if (rel_y >= 0) begin
            abs_y = rel_y;
        end else begin
            abs_y = -rel_y;
        end
        
        // Pac-Man is bigger: 60x60 pixels (radius = 30)
        dist_sq = rel_x * rel_x + rel_y * rel_y;
        
        // Draw circle (radius = 30)
        if (dist_sq < 900) begin  // 30^2 = 900
            // Triangle mouth: opens to the right, angle controlled by mouth_angle
            // mouth_angle: 0 = closed, 63 = wide open
            // Mouth slope = mouth_angle / 64 (approximately)
            if (rel_x > 0) begin
                // Triangle mouth: check if abs(rel_y) < rel_x * (mouth_angle/64)
                // For efficiency: abs_y * 64 < rel_x * mouth_angle
                if ((abs_y << 6) < (rel_x * mouth_angle)) begin  // Inside triangle mouth
                    draw_pacman = 24'h0;  // Inside mouth - don't draw
                end else begin
                    draw_pacman = COLOR_PACMAN;
                end
            end else begin
                // Left side - always draw (no mouth)
                draw_pacman = COLOR_PACMAN;
            end
        end else begin
            draw_pacman = 24'h0;  // Transparent (outside circle)
        end
    end
endfunction

// Function to draw ghosts with proper shape (half circle on top, waves underneath, eyes)
function [23:0] draw_ghost;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] gx, gy;  // Ghost center X, Y
    input [23:0] ghost_color;  // Ghost color
    reg [10:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    reg signed [10:0] signed_rel_x, signed_rel_y;
    reg [11:0] dist_sq;
    begin
        if (px >= gx) begin
            rel_x = px - gx;
            abs_x = px - gx;
            signed_rel_x = px - gx;
        end else begin
            rel_x = gx - px;
            abs_x = gx - px;
            signed_rel_x = -(gx - px);
        end
        
        if (py >= gy) begin
            rel_y = py - gy;
            abs_y = py - gy;
            signed_rel_y = py - gy;
        end else begin
            rel_y = gy - py;
            abs_y = gy - py;
            signed_rel_y = -(gy - py);
        end
        
        draw_ghost = 24'h0;  // Transparent by default
        
        // Ghost is roughly 40x50 pixels (bigger)
        if (abs_x <= 20 && abs_y <= 25) begin
            // Top half circle (abs_y < 20)
            if (signed_rel_y < -5) begin
                // Calculate distance from center for rounded top
                dist_sq = abs_x * abs_x + (signed_rel_y + 5) * (signed_rel_y + 5);
                if (dist_sq < 400) begin  // 20^2 = 400
                    draw_ghost = ghost_color;
                end
            end
            // Rectangular body (abs_y >= -5 and < 20)
            else if (signed_rel_y >= -5 && signed_rel_y < 20) begin
                if (abs_x <= 20) begin
                    draw_ghost = ghost_color;
                end
            end
            // Wavy bottom (abs_y >= 20 and <= 25)
            else if (signed_rel_y >= 20 && signed_rel_y <= 25) begin
                // Create wave pattern: 5 waves
                if ((signed_rel_x >= -20 && signed_rel_x < -12 && signed_rel_y >= 20 && signed_rel_y < 22) ||
                    (signed_rel_x >= -12 && signed_rel_x < -4 && signed_rel_y >= 20 && signed_rel_y < 24) ||
                    (signed_rel_x >= -4 && signed_rel_x < 4 && signed_rel_y >= 20 && signed_rel_y < 25) ||
                    (signed_rel_x >= 4 && signed_rel_x < 12 && signed_rel_y >= 20 && signed_rel_y < 24) ||
                    (signed_rel_x >= 12 && signed_rel_x < 20 && signed_rel_y >= 20 && signed_rel_y < 22)) begin
                    draw_ghost = ghost_color;
                end
            end
            
            // Ghost eyes (two white ovals)
            if (((signed_rel_x >= -12 && signed_rel_x <= -6) && (signed_rel_y >= -10 && signed_rel_y <= -4)) ||
                ((signed_rel_x >= 6 && signed_rel_x <= 12) && (signed_rel_y >= -10 && signed_rel_y <= -4))) begin
                draw_ghost = 24'hFF_FF_FF;  // White eyes
            end
            
            // Eye pupils (black dots)
            if (((signed_rel_x >= -10 && signed_rel_x <= -8) && (signed_rel_y >= -8 && signed_rel_y <= -6)) ||
                ((signed_rel_x >= 8 && signed_rel_x <= 10) && (signed_rel_y >= -8 && signed_rel_y <= -6))) begin
                draw_ghost = 24'h00_00_00;  // Black pupils
            end
        end
    end
endfunction

// Position 5 ghosts above/around the HUGE logo
wire [10:0] ghost_x [0:4];
wire [10:0] ghost_y_static;
wire [23:0] maze_color;
wire [23:0] ghost_color [0:4];

assign ghost_x[0] = 150;   // Pink ghost (left side near R)
assign ghost_x[1] = 550;   // Red ghost (above O)  
assign ghost_x[2] = 960;   // Orange ghost (center)
assign ghost_x[3] = 1180;  // Cyan ghost (near first S)
assign ghost_x[4] = 1650;  // Blue ghost (right side near second S)
assign ghost_y_static = 150;  // Above logo, near top
assign maze_color = draw_maze(HCNT, VCNT, 0);  // No offset
assign ghost_color[0] = draw_ghost(HCNT, VCNT, ghost_x[0], ghost_y_static, COLOR_GHOST_PINK);   // Pink
assign ghost_color[1] = draw_ghost(HCNT, VCNT, ghost_x[1], ghost_y_static, COLOR_GHOST_RED);    // Red
assign ghost_color[2] = draw_ghost(HCNT, VCNT, ghost_x[2], ghost_y_static, COLOR_GHOST_BLUE);   // Orange (but using blue color)
assign ghost_color[3] = draw_ghost(HCNT, VCNT, ghost_x[3], ghost_y_static, COLOR_GHOST_GREEN);  // Cyan (but using green)
assign ghost_color[4] = draw_ghost(HCNT, VCNT, ghost_x[4], ghost_y_static, COLOR_GHOST_PURPLE); // Blue (but using purple)

// Static Pac-Man positioned right underneath the line of ghosts
wire [10:0] pacman_x_static;
wire [10:0] pacman_y_static;
wire [7:0]  pacman_mouth_static;
wire [23:0] pacman_color_static;

assign pacman_x_static = 960;        // Center horizontally
assign pacman_y_static = 250;        // Below ghosts (ghosts at 150, ghosts ~50 tall, gap ~50)
assign pacman_mouth_static = 8'd45;  // Static mouth angle (moderately open)
assign pacman_color_static = draw_pacman(HCNT, VCNT, pacman_x_static, pacman_y_static, pacman_mouth_static);

// Function to draw dots/pellets (white dots in empty spaces)
function [23:0] draw_dots;
    input [10:0] px, py;  // Pixel coordinates
    input [23:0] maze_pixel;  // Maze color at this pixel
    begin
        // Draw white dots (6x6 pixels) only in empty spaces (where maze is transparent)
        if (maze_pixel == 24'h0 &&  // No maze element at this location
            px >= 80 && px < 1840 &&  // Within bounds
            py >= 80 && py < 1000 &&
            (px % 50 >= 22 && px % 50 < 28) &&  // Dots every 50 pixels (6 pixels wide)
            (py % 50 >= 22 && py % 50 < 28)) begin  // 6 pixels tall
            draw_dots = 24'hFF_FF_FF;  // White dot
        end else begin
            draw_dots = 24'h0;  // Transparent
        end
    end
endfunction

wire [23:0] dot_color;
assign dot_color = draw_dots(HCNT, VCNT, maze_color);

integer j;
always @(posedge clk_i) begin
    if (rst_i) begin
        HD <= 1'b0;
        VD <= 1'b0;
        HCNT <= 12'd0;
        VCNT <= 11'd0;
        frame_counter <= 26'd0;
        for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
            snowflake_x[j] <= (j * 160) % 1920;  // Distribute across screen
            snowflake_y[j] <= (j * 90) % 1080;   // Stagger vertically
            snowflake_rot[j] <= j * 21;           // Different rotation
            snowflake_speed[j] <= (j % 8) + 1;    // Speed 1-8
        end
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
            
            // Animate snowflakes
            for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
                // Move snowflake down
                if (snowflake_y[j] + snowflake_speed[j] >= 1080) begin
                    // Reset to top with random X position
                    snowflake_y[j] <= 11'd0;
                    snowflake_x[j] <= (snowflake_x[j] + 137) % 1920;  // Pseudo-random
                end else begin
                    snowflake_y[j] <= snowflake_y[j] + snowflake_speed[j];
                end
                
                // Rotate snowflake
                snowflake_rot[j] <= snowflake_rot[j] + (j % 4) + 1;  // Different rotation speeds
            end
        end else if (HR) begin  // Horizontal rising edge (entering blank = end of line)
            VCNT <= VCNT + 1;
        end
        
        // Draw background (black like classic Pac-Man)
        vid_rgb_d1 <= 24'h00_00_00;  // Black background
        
        // Draw dots/pellets first (behind everything)
        if (dot_color != 24'h0) begin
            vid_rgb_d1 <= dot_color;
        end
        
        // Draw maze (letters and borders on top of dots)
        if (maze_color != 24'h0) begin
            vid_rgb_d1 <= maze_color;
        end
        
        // Draw 5 ghosts (on top of maze)
        for (j = 0; j < 5; j = j + 1) begin
            if (ghost_color[j] != 24'h0) begin
                vid_rgb_d1 <= ghost_color[j];
            end
        end
        
        // Draw static Pac-Man (below ghosts, on top of maze)
        if (pacman_color_static != 24'h0) begin
            vid_rgb_d1 <= pacman_color_static;
        end
        
        // Draw snowflakes on top (check each snowflake, later ones draw on top)
        for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
            if (snowflake_color[j] != 24'h0) begin
                vid_rgb_d1 <= snowflake_color[j];
            end
        end
        
        dvh_sync_d1 <= dvh_sync_i;
    end
end

// OUTPUT
assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule
