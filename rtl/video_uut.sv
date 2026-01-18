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
localparam [23:0] COLOR_LETTER_R      = 24'hFF_00_00;  // RED for R
localparam [23:0] COLOR_LETTER_O      = 24'hFF_FF_00;  // YELLOW for O
localparam [23:0] COLOR_LETTER_S1     = 24'hFF_80_00;  // ORANGE for first S
localparam [23:0] COLOR_LETTER_S2     = 24'h00_FF_00;  // GREEN for second S
localparam [23:0] COLOR_GHOST_BLUE   = 24'h00_80_FF;  // Blue ghost
localparam [23:0] COLOR_GHOST_RED    = 24'hFF_00_00;  // Red ghost
localparam [23:0] COLOR_GHOST_PINK   = 24'hFF_B0_FF;  // Pink ghost
localparam [23:0] COLOR_GHOST_GREEN  = 24'h00_FF_00;  // Green ghost
localparam [23:0] COLOR_GHOST_PURPLE = 24'h80_00_FF;  // Purple ghost
localparam [23:0] COLOR_PACMAN    = 24'hFF_FF_00;  // Yellow Pac-Man

// Pac-Man animation
reg signed [10:0] pacman_x_offset;  // Pac-Man horizontal movement offset
reg [7:0] pacman_mouth_angle;  // Pac-Man mouth animation (0-63 for open/close)

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
    reg [10:0] thickness_outer, thickness_inner;
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
        
        // SMALLER ROSS letters for Pac-Man theme - double-lined hollow letters
        letter_start_x = center_x - 400;  // More centered, smaller span
        letter_width = 160;  // Smaller width (was 320)
        letter_height = 250;  // Smaller height (was 600)
        thickness_outer = 12;  // Thinner outer line
        thickness_inner = 8;   // Gap between double lines (hollow space)
        
        // Draw "ROSS" letters as hollow double-line letters (Smaller for Pac-Man theme)
        // R - First letter (RED) - Proper pixelized R with double lines, HOLLOW
        if (px >= letter_start_x && px < letter_start_x + letter_width && py >= center_y - 125 && py < center_y + 125) begin
            // Outer R shape (pixelized) - Proper R with diagonal leg
            if ((px >= letter_start_x && px < letter_start_x + thickness_outer && py >= center_y - 125 && py < center_y + 125) ||  // Left vertical (outer) - full height
                (px >= letter_start_x + thickness_outer && px < letter_start_x + letter_width - 10 && py >= center_y - 125 && py < center_y - 125 + thickness_outer) ||  // Top horizontal (outer)
                (px >= letter_start_x + letter_width - 10 - thickness_outer && px < letter_start_x + letter_width - 10 && py >= center_y - 125 + thickness_outer && py < center_y - 5) ||  // Top right vertical (outer)
                (px >= letter_start_x + thickness_outer && px < letter_start_x + letter_width - 10 && py >= center_y - 5 && py < center_y - 5 + thickness_outer) ||  // Middle horizontal (outer)
                (px >= letter_start_x + letter_width - 10 - thickness_outer && px < letter_start_x + letter_width - 10 && py >= center_y - 5 && py < center_y - 5 + thickness_outer) ||  // Middle right corner (outer)
                (px >= letter_start_x + letter_width - 40 && px < letter_start_x + letter_width - 28 && py >= center_y + 40 && py < center_y + 125)) begin  // Bottom right leg (outer)
                draw_maze = COLOR_LETTER_R;  // RED
            end
            // Inner R shape (void/hollow for double-line effect) - creates the hollow outline
            else if ((px >= letter_start_x + thickness_outer && px < letter_start_x + thickness_outer + thickness_inner && py >= center_y - 125 + thickness_outer && py < center_y + 125 - thickness_outer) ||  // Left vertical (inner)
                     (px >= letter_start_x + thickness_outer + thickness_inner && px < letter_start_x + letter_width - 10 - thickness_outer && py >= center_y - 125 + thickness_outer && py < center_y - 125 + thickness_outer + thickness_inner) ||  // Top horizontal (inner)
                     (px >= letter_start_x + letter_width - 10 - thickness_outer - thickness_inner && px < letter_start_x + letter_width - 10 - thickness_outer && py >= center_y - 125 + thickness_outer + thickness_inner && py < center_y - 5 - thickness_outer) ||  // Top right vertical (inner)
                     (px >= letter_start_x + thickness_outer + thickness_inner && px < letter_start_x + letter_width - 10 - thickness_outer && py >= center_y - 5 + thickness_outer && py < center_y - 5 + thickness_outer + thickness_inner) ||  // Middle horizontal (inner)
                     (px >= letter_start_x + letter_width - 40 + thickness_outer && px < letter_start_x + letter_width - 28 - thickness_outer && py >= center_y + 40 + thickness_outer && py < center_y + 125 - thickness_outer)) begin  // Bottom right leg (inner)
                draw_maze = COLOR_LETTER_R;  // RED
            end
        end
        
        // O - Second letter (YELLOW) - Proper pixelized O rectangle with double lines
        if (px >= letter_start_x + 360 && px < letter_start_x + 360 + letter_width && py >= center_y - 300 && py < center_y + 300) begin
            // Outer O shape (rectangular)
            if ((px >= letter_start_x + 360 && px < letter_start_x + 360 + thickness_outer && py >= center_y - 300 && py < center_y + 300) ||  // Left vertical (outer)
                (px >= letter_start_x + 360 + letter_width - thickness_outer && px < letter_start_x + 360 + letter_width && py >= center_y - 300 && py < center_y + 300) ||  // Right vertical (outer)
                (px >= letter_start_x + 360 + thickness_outer && px < letter_start_x + 360 + letter_width - thickness_outer && py >= center_y - 300 && py < center_y - 300 + thickness_outer) ||  // Top horizontal (outer)
                (px >= letter_start_x + 360 + thickness_outer && px < letter_start_x + 360 + letter_width - thickness_outer && py >= center_y + 300 - thickness_outer && py < center_y + 300)) begin  // Bottom horizontal (outer)
                draw_maze = COLOR_LETTER_O;  // YELLOW
            end
            // Inner O shape (double-line effect)
            else if ((px >= letter_start_x + 360 + thickness_outer && px < letter_start_x + 360 + 2*thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y + 300 - thickness_outer) ||  // Left vertical (inner)
                     (px >= letter_start_x + 360 + letter_width - 2*thickness_outer && px < letter_start_x + 360 + letter_width - thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y + 300 - thickness_outer) ||  // Right vertical (inner)
                     (px >= letter_start_x + 360 + 2*thickness_outer && px < letter_start_x + 360 + letter_width - 2*thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y - 300 + 2*thickness_outer) ||  // Top horizontal (inner)
                     (px >= letter_start_x + 360 + 2*thickness_outer && px < letter_start_x + 360 + letter_width - 2*thickness_outer && py >= center_y + 300 - 2*thickness_outer && py < center_y + 300 - thickness_outer)) begin  // Bottom horizontal (inner)
                draw_maze = COLOR_LETTER_O;  // YELLOW
            end
        end
        
        // S - Third letter (ORANGE) - Proper pixelized S with double lines - FIXED
        if (px >= letter_start_x + 720 && px < letter_start_x + 720 + letter_width && py >= center_y - 300 && py < center_y + 300) begin
            // Outer S shape - corrected
            if ((px >= letter_start_x + 720 && px < letter_start_x + 720 + thickness_outer && py >= center_y - 300 && py < center_y - 10) ||  // Top left vertical (outer)
                (px >= letter_start_x + 720 + thickness_outer && px < letter_start_x + 720 + letter_width && py >= center_y - 300 && py < center_y - 300 + thickness_outer) ||  // Top horizontal (outer)
                (px >= letter_start_x + 720 + letter_width - thickness_outer && px < letter_start_x + 720 + letter_width && py >= center_y - 300 + thickness_outer && py < center_y - 10) ||  // Top right vertical (outer)
                (px >= letter_start_x + 720 && px < letter_start_x + 720 + letter_width && py >= center_y - 10 && py < center_y - 10 + thickness_outer) ||  // Middle horizontal (outer)
                (px >= letter_start_x + 720 && px < letter_start_x + 720 + thickness_outer && py >= center_y - 10 + thickness_outer && py < center_y + 300 - thickness_outer) ||  // Bottom left vertical (outer)
                (px >= letter_start_x + 720 + letter_width - thickness_outer && px < letter_start_x + 720 + letter_width && py >= center_y - 10 + thickness_outer && py < center_y + 300) ||  // Bottom right vertical (outer)
                (px >= letter_start_x + 720 && px < letter_start_x + 720 + letter_width - thickness_outer && py >= center_y + 300 - thickness_outer && py < center_y + 300)) begin  // Bottom horizontal (outer)
                draw_maze = COLOR_LETTER_S1;  // ORANGE
            end
            // Inner S shape (double-line effect)
            else if ((px >= letter_start_x + 720 + thickness_outer && px < letter_start_x + 720 + 2*thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y - 10 - thickness_inner) ||  // Top left vertical (inner)
                     (px >= letter_start_x + 720 + 2*thickness_outer && px < letter_start_x + 720 + letter_width - thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y - 300 + 2*thickness_outer) ||  // Top horizontal (inner)
                     (px >= letter_start_x + 720 + letter_width - 2*thickness_outer && px < letter_start_x + 720 + letter_width - thickness_outer && py >= center_y - 300 + 2*thickness_outer && py < center_y - 10) ||  // Top right vertical (inner)
                     (px >= letter_start_x + 720 + thickness_outer && px < letter_start_x + 720 + letter_width - thickness_outer && py >= center_y - 10 + thickness_outer && py < center_y - 10 + 2*thickness_outer) ||  // Middle horizontal (inner)
                     (px >= letter_start_x + 720 + thickness_outer && px < letter_start_x + 720 + 2*thickness_outer && py >= center_y - 10 + 2*thickness_outer && py < center_y + 300 - 2*thickness_outer) ||  // Bottom left vertical (inner)
                     (px >= letter_start_x + 720 + letter_width - 2*thickness_outer && px < letter_start_x + 720 + letter_width - thickness_outer && py >= center_y - 10 + 2*thickness_outer && py < center_y + 300 - thickness_outer) ||  // Bottom right vertical (inner)
                     (px >= letter_start_x + 720 + thickness_outer && px < letter_start_x + 720 + letter_width - 2*thickness_outer && py >= center_y + 300 - 2*thickness_outer && py < center_y + 300 - thickness_outer)) begin  // Bottom horizontal (inner)
                draw_maze = COLOR_LETTER_S1;  // ORANGE
            end
        end
        
        // S - Fourth letter (GREEN) - Proper pixelized S with double lines - FIXED (same as third)
        if (px >= letter_start_x + 1080 && px < letter_start_x + 1080 + letter_width && py >= center_y - 300 && py < center_y + 300) begin
            // Outer S shape - corrected
            if ((px >= letter_start_x + 1080 && px < letter_start_x + 1080 + thickness_outer && py >= center_y - 300 && py < center_y - 10) ||  // Top left vertical (outer)
                (px >= letter_start_x + 1080 + thickness_outer && px < letter_start_x + 1080 + letter_width && py >= center_y - 300 && py < center_y - 300 + thickness_outer) ||  // Top horizontal (outer)
                (px >= letter_start_x + 1080 + letter_width - thickness_outer && px < letter_start_x + 1080 + letter_width && py >= center_y - 300 + thickness_outer && py < center_y - 10) ||  // Top right vertical (outer)
                (px >= letter_start_x + 1080 && px < letter_start_x + 1080 + letter_width && py >= center_y - 10 && py < center_y - 10 + thickness_outer) ||  // Middle horizontal (outer)
                (px >= letter_start_x + 1080 && px < letter_start_x + 1080 + thickness_outer && py >= center_y - 10 + thickness_outer && py < center_y + 300 - thickness_outer) ||  // Bottom left vertical (outer)
                (px >= letter_start_x + 1080 + letter_width - thickness_outer && px < letter_start_x + 1080 + letter_width && py >= center_y - 10 + thickness_outer && py < center_y + 300) ||  // Bottom right vertical (outer)
                (px >= letter_start_x + 1080 && px < letter_start_x + 1080 + letter_width - thickness_outer && py >= center_y + 300 - thickness_outer && py < center_y + 300)) begin  // Bottom horizontal (outer)
                draw_maze = COLOR_LETTER_S2;  // GREEN
            end
            // Inner S shape (double-line effect)
            else if ((px >= letter_start_x + 1080 + thickness_outer && px < letter_start_x + 1080 + 2*thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y - 10 - thickness_inner) ||  // Top left vertical (inner)
                     (px >= letter_start_x + 1080 + 2*thickness_outer && px < letter_start_x + 1080 + letter_width - thickness_outer && py >= center_y - 300 + thickness_outer && py < center_y - 300 + 2*thickness_outer) ||  // Top horizontal (inner)
                     (px >= letter_start_x + 1080 + letter_width - 2*thickness_outer && px < letter_start_x + 1080 + letter_width - thickness_outer && py >= center_y - 300 + 2*thickness_outer && py < center_y - 10) ||  // Top right vertical (inner)
                     (px >= letter_start_x + 1080 + thickness_outer && px < letter_start_x + 1080 + letter_width - thickness_outer && py >= center_y - 10 + thickness_outer && py < center_y - 10 + 2*thickness_outer) ||  // Middle horizontal (inner)
                     (px >= letter_start_x + 1080 + thickness_outer && px < letter_start_x + 1080 + 2*thickness_outer && py >= center_y - 10 + 2*thickness_outer && py < center_y + 300 - 2*thickness_outer) ||  // Bottom left vertical (inner)
                     (px >= letter_start_x + 1080 + letter_width - 2*thickness_outer && px < letter_start_x + 1080 + letter_width - thickness_outer && py >= center_y - 10 + 2*thickness_outer && py < center_y + 300 - thickness_outer) ||  // Bottom right vertical (inner)
                     (px >= letter_start_x + 1080 + thickness_outer && px < letter_start_x + 1080 + letter_width - 2*thickness_outer && py >= center_y + 300 - 2*thickness_outer && py < center_y + 300 - thickness_outer)) begin  // Bottom horizontal (inner)
                draw_maze = COLOR_LETTER_S2;  // GREEN
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

// Animated Pac-Man position and mouth - with animation
wire [10:0] pacman_x_pos;
wire signed [11:0] pacman_x_base;
assign pacman_x_base = 960 - 400;  // Base X position (more centered)
assign pacman_x_pos = pacman_x_base + pacman_x_offset;  // Animated X position

// Position 5 ghosts above the HUGE logo (EQUALLY spaced across the screen)
assign ghost_x[0] = 960 - 700 + 160;   // Blue ghost (above R)
assign ghost_x[1] = 960 - 700 + 440;   // Red ghost (above O)  
assign ghost_x[2] = 960 - 700 + 720;   // Pink ghost (between O and S1)
assign ghost_x[3] = 960 - 700 + 1000;  // Green ghost (above first S)
assign ghost_x[4] = 960 - 700 + 1280;  // Purple ghost (above second S)
assign ghost_y_static = 540 - 400;  // Above HUGE logo, higher up
assign pacman_y_static = 540 + 420;  // Below HUGE logo, lower down
assign maze_color = draw_maze(HCNT, VCNT, 0);  // No offset
assign ghost_color[0] = draw_ghost(HCNT, VCNT, ghost_x[0], ghost_y_static, COLOR_GHOST_BLUE);   // Blue
assign ghost_color[1] = draw_ghost(HCNT, VCNT, ghost_x[1], ghost_y_static, COLOR_GHOST_RED);    // Red
assign ghost_color[2] = draw_ghost(HCNT, VCNT, ghost_x[2], ghost_y_static, COLOR_GHOST_PINK);   // Pink
assign ghost_color[3] = draw_ghost(HCNT, VCNT, ghost_x[3], ghost_y_static, COLOR_GHOST_GREEN);  // Green
assign ghost_color[4] = draw_ghost(HCNT, VCNT, ghost_x[4], ghost_y_static, COLOR_GHOST_PURPLE); // Purple
assign pacman_color = draw_pacman(HCNT, VCNT, pacman_x_pos, pacman_y_static, pacman_mouth_angle);  // Pac-Man ANIMATED

// Function to draw dots/pellets (BIGGER white dots, including inside letter voids)
function [23:0] draw_dots;
    input [10:0] px, py;  // Pixel coordinates
    input [23:0] maze_pixel;  // Maze color at this pixel
    reg [10:0] center_x, center_y;
    reg [10:0] letter_start_x;
    reg in_letter_void;
    begin
        center_x = 960;
        center_y = 540;
        letter_start_x = center_x - 700;
        in_letter_void = 0;
        
        // Check if we're inside a letter void (between double lines)
        // R void area
        if (px > letter_start_x + 40 && px < letter_start_x + 280 && py > center_y - 280 && py < center_y + 280) begin
            in_letter_void = 1;
        end
        // O void area
        if (px > letter_start_x + 360 + 40 && px < letter_start_x + 360 + 280 && py > center_y - 280 && py < center_y + 280) begin
            in_letter_void = 1;
        end
        // First S void area
        if (px > letter_start_x + 720 + 40 && px < letter_start_x + 720 + 280 && py > center_y - 280 && py < center_y + 280) begin
            in_letter_void = 1;
        end
        // Second S void area
        if (px > letter_start_x + 1080 + 40 && px < letter_start_x + 1080 + 280 && py > center_y - 280 && py < center_y + 280) begin
            in_letter_void = 1;
        end
        
        // Draw BIGGER white dots (6x6 pixels) in empty spaces and inside letter voids
        if ((maze_pixel == 24'h0 || in_letter_void) &&  // Not a wall OR inside letter void
            px >= 80 && px < 1840 &&  // Within bounds
            py >= 80 && py < 1000 &&
            (px % 50 >= 22 && px % 50 < 28) &&  // Bigger dots every 50 pixels (6 pixels wide)
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
        maze_offset_y <= 11'd0;
        pacman_mouth_angle <= 8'd0;
        pacman_x_offset <= 11'd0;
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
            
            // No maze animation - static
            maze_offset_y <= 11'd0;
            
            // Animate Pac-Man mouth (open/close cycle)
            // Mouth opens and closes smoothly: 0 -> 63 -> 0
            if (frame_counter[5:0] < 32) begin
                pacman_mouth_angle <= frame_counter[5:0] << 1;  // Opening: 0 to 63
            end else begin
                pacman_mouth_angle <= (63 - frame_counter[5:0]) << 1;  // Closing: 63 to 0
            end
            
            // Animate Pac-Man horizontal movement (slow left-right: +/-10 pixels)
            // Use sine-like approximation: move 10px left and right over ~128 frames
            if (frame_counter[7:0] < 64) begin
                pacman_x_offset <= (frame_counter[7:0] * 10) / 64;  // Move right: 0 to +10
            end else if (frame_counter[7:0] < 128) begin
                pacman_x_offset <= 10 - ((frame_counter[7:0] - 64) * 10) / 64;  // Back to 0
            end else if (frame_counter[7:0] < 192) begin
                pacman_x_offset <= -((frame_counter[7:0] - 128) * 10) / 64;  // Move left: 0 to -10
            end else begin
                pacman_x_offset <= -10 + ((frame_counter[7:0] - 192) * 10) / 64;  // Back to 0
            end
            
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
        
        // Draw dots/pellets first (behind everything, but NOT on Pac-Man!)
        if (dot_color != 24'h0 && pacman_color == 24'h0) begin  // Only draw dots where Pac-Man is NOT
            vid_rgb_d1 <= dot_color;
        end
        
        // Draw maze (dark blue)
        if (maze_color != 24'h0) begin
            vid_rgb_d1 <= maze_color;
        end
        
        // Draw Pac-Man (static, on top of maze)
        if (pacman_color != 24'h0) begin
            vid_rgb_d1 <= pacman_color;
        end
        
        // Draw 5 ghosts (static, on top of maze)
        for (j = 0; j < 5; j = j + 1) begin
            if (ghost_color[j] != 24'h0) begin
                vid_rgb_d1 <= ghost_color[j];
            end
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
