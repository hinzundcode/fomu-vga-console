// pinout:
// user_1 is R, G and B (VGA pins 1, 2 and 3)
// user_2 is Ground
// user_3 is HSYNC (VGA pin 13)
// user_4 is VSYNC (VGA pin 15)

`include "hvsync_generator.v"
`include "font.v"

module vga(
	input clk,
	output hsync,
	output vsync,
	output color,
	output [11:0] framebuffer_addr,
	input [7:0] framebuffer_data
);
	wire display_on;
	wire [9:0] hpos;
	wire [9:0] vpos;
	wire [7:0] glyph;
	wire [0:7] glyph_row;
	
	hvsync_generator hvsync_generator (
		.clk(clk),
		.reset(0),
		.hsync(hsync),
		.vsync(vsync),
		.display_on(display_on),
		.hpos(hpos),
		.vpos(vpos),
	);
	
	assign framebuffer_addr = buffer_y * 80 + buffer_x;
	assign glyph = framebuffer_data;
	
	font font(
		.clk(clk),
		.glyph(glyph),
		.y(glyph_y),
		.row(glyph_row),
	);
	
	// --> [framebuffer] --clk--> [font] --clk--> {rendering}
	// loading the current character from the framebuffer takes 1 clock cycle
	// loading the glyph from font memory takes another clock cycle
	// which means everything is 2 clock cycles behind
	// solution: fetch everything 2 clock cycles ahead by adding 2 to the x position
	wire [15:0] prefetch_hpos = hpos >= 640 ? 0 : hpos + 2;
	// and already fetch the next line after visible area/during blank
	wire [15:0] prefetch_vpos = vpos >= 480 ? 0 : (hpos >= 640 ? vpos + 1 : vpos);
	
	wire [7:0] buffer_y = prefetch_vpos / 16;
	wire [7:0] buffer_x = prefetch_hpos / 8;
	
	wire [3:0] glyph_y = prefetch_vpos % 16;
	wire [2:0] glyph_x = hpos % 8;
	
	assign color = display_on && glyph_row[glyph_x];
endmodule
