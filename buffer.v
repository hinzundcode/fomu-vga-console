module buffer_mem(
	input clk,
	input [11:0] addr,
	output reg [7:0] data
);

	reg [7:0] mem [0:2399];
	initial begin
		mem[0]  = "H";
		mem[1]  = "e";
		mem[2]  = "l";
		mem[3]  = "l";
		mem[4]  = "o";
		mem[5]  = " ";
		mem[6]  = "f";
		mem[7]  = "r";
		mem[8]  = "o";
		mem[9]  = "m";
		mem[10] = " ";
		mem[11] = "f";
		mem[12] = "o";
		mem[13] = "m";
		mem[14] = "u";
	end
	
	always @(posedge clk) begin
		data <= mem[addr];
	end

endmodule

module buffer(
	input clk,
	input [7:0] x,
	input [7:0] y,
	output reg [7:0] glyph
);

buffer_mem buffer_mem(
	.clk(clk),
	.addr(buffer_mem_addr),
	.data(glyph),
);

wire [11:0] buffer_mem_addr = y * 80 + x;

endmodule
