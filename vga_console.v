// pinout:
// user_1 is R, G and B (VGA pins 1, 2 and 3)
// user_2 is Ground
// user_3 is HSYNC (VGA pin 13)
// user_4 is VSYNC (VGA pin 15)

`include "hvsync_generator.v"
`include "buffer.v"
`include "font.v"

module vga_console(
	input clk,
	output hsync,
	output vsync,
	output color
);
	wire display_on;
	wire [10:0] hpos;
	wire [10:0] vpos;
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
	
	buffer buffer(
		.clk(clk),
		.x(buffer_x),
		.y(buffer_y),
		.glyph(glyph),
	);
	
	font font(
		.clk(clk),
		.glyph(glyph),
		.y(glyph_y),
		.row(glyph_row),
	);
	
	// --> [buffer] --clk--> [font] --clk--> {rendering}
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


module top (
		input clki,
		output user_1,
		output user_2,
		output user_3,
		output user_4,
		output usb_dp,
		output usb_dn,
		output usb_dp_pu
);
	assign usb_dp = 1'b0;
	assign usb_dn = 1'b0;
	assign usb_dp_pu = 1'b0;
	
	wire clk;
	SB_GB clk_gb (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
		.GLOBAL_BUFFER_OUTPUT(clk)
	);
	
	wire pclk;
	// 640x480 @60Hz VGA needs a 25.175MHz pixel clock
	// using the pll to generate a 25.125MHz clock from 48MHz
	// ($ icepll -i 48 -o 25.175)
	SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"),
		.PLLOUT_SELECT("GENCLK"),
		.DIVR(4'b0011), // R = 3
		.DIVF(7'b1000010), // F = 66
		.DIVQ(3'b101), // Q = 5
		.FILTER_RANGE(3'b001),
	) uut (
		.REFERENCECLK(clk),
		.PLLOUTCORE(pclk),
		.RESETB(1'b1),
		.BYPASS(1'b0)
	);

	vga_console vga_console (
		.clk(pclk),
		.hsync(user_3),
		.vsync(user_4),
		.color(user_1),
	);
	
	assign user_2 = 'b0;
endmodule
