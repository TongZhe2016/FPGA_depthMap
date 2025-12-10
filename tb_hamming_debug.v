`timescale 1ns/1ps

module tb_hamming_debug;

reg clk, rst_n;
reg [7:0] census_left, census_right;
reg valid_in;
wire [3:0] hamming_dist;
wire valid_out;

// 实例化
hamming_distance #(.CENSUS_WIDTH(8)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .census_left(census_left),
    .census_right(census_right),
    .valid_in(valid_in),
    .hamming_dist(hamming_dist),
    .valid_out(valid_out)
);

// 时钟
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

// 测试
initial begin
    $display("\n=== Simple Hamming Distance Debug ===\n");
    
    // 复位
    rst_n = 0;
    census_left = 0;
    census_right = 0;
    valid_in = 0;
    
    #50;
    rst_n = 1;
    #20;
    
    $display("Test: Input two identical codes");
    @(posedge clk);
    census_left = 8'b01010101;
    census_right = 8'b01010101;
    valid_in = 1;
    $display("[T=%0t] Input: Left=%b, Right=%b, valid_in=%b", $time, census_left, census_right, valid_in);
    
    // 观察每个时钟周期
    repeat(10) begin
        @(posedge clk);
        $display("[T=%0t] valid_in=%b, valid_out=%b, hamming_dist=%d", $time, valid_in, valid_out, hamming_dist);
        if (valid_in == 1) valid_in = 0;  // 只保持一个周期
    end
    
    #100;
    $display("\n=== Test completed ===\n");
    $finish;
end

// 监控内部信号
initial begin
    $monitor("[Monitor T=%0t] rst_n=%b, valid_in=%b, valid_out=%b, dist=%d", 
             $time, rst_n, valid_in, valid_out, hamming_dist);
end

endmodule

