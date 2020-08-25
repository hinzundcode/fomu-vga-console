module clock12(
    input clk48,
    output clk12
);

reg [1:0] count = 0;

always @(posedge clk48) begin
    count <= count + 1;
end

assign clk12 = count == 0 || count == 1;

endmodule
