module font_mem(
	input clk,
	input [11:0] addr,
	output reg [0:7] data
);

	reg [0:7] mem [0:4095];
	initial begin
		$readmemb("font.mem", mem);
	end
	
	always @(posedge clk) begin
		data <= mem[addr];
	end

endmodule

module font(
	input clk,
	input [7:0] glyph,
	input [3:0] y,
	output reg [0:7] row
);

font_mem font_mem(
	.clk(clk),
	.addr(font_mem_addr),
	.data(row),
);

wire [11:0] font_mem_addr = glyph * 16 + y;

endmodule