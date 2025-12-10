`timescale 1ns/1ps
/*****************************************************************************/
/******************** Hamming Distance Testbench *****************************/
/*****************************************************************************/

module tb_hamming_distance;

// 时钟和复位
reg clk;
reg rst_n;

// 输入
reg [7:0] census_left;
reg [7:0] census_right;
reg valid_in;

// 输出
wire [3:0] hamming_dist;
wire valid_out;

// 实例化待测模块
hamming_distance #(
    .CENSUS_WIDTH(8)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .census_left(census_left),
    .census_right(census_right),
    .valid_in(valid_in),
    .hamming_dist(hamming_dist),
    .valid_out(valid_out)
);

// 时钟生成：50MHz
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

// 测试用例
initial begin
    $dumpfile("hamming_distance.vcd");
    $dumpvars(0, tb_hamming_distance);
    
    // 复位
    rst_n = 0;
    census_left = 0;
    census_right = 0;
    valid_in = 0;
    
    #50;
    rst_n = 1;
    #20;
    
    $display("\n=== Hamming Distance Test Cases ===\n");
    
    // ========== 测试案例1：完全相同 ==========
    $display("Test 1: Identical codes (distance = 0)");
    @(posedge clk);
    census_left = 8'b01010101;
    census_right = 8'b01010101;
    valid_in = 1;
    $display("  Left:  %b", census_left);
    $display("  Right: %b", census_right);
    
    @(posedge clk);
    valid_in = 0;
    
    // 等待流水线输出：在valid_out拉高的那个周期检查
    wait(valid_out == 1);
    @(posedge clk);  // 同步到时钟边沿
    
    $display("  Hamming distance: %d (expected: 0)", hamming_dist);
    if (hamming_dist == 0) begin
        $display("  ✓ PASS\n");
    end else begin
        $display("  ✗ FAIL\n");
    end
    
    // ========== 测试案例2：完全不同 ==========
    $display("Test 2: Completely different (distance = 8)");
    @(posedge clk);
    census_left = 8'b11111111;
    census_right = 8'b00000000;
    valid_in = 1;
    $display("  Left:  %b", census_left);
    $display("  Right: %b", census_right);
    
    @(posedge clk);
    valid_in = 0;
    
    wait(valid_out == 1);
    @(posedge clk);
    
    $display("  Hamming distance: %d (expected: 8)", hamming_dist);
    if (hamming_dist == 8) begin
        $display("  ✓ PASS\n");
    end else begin
        $display("  ✗ FAIL\n");
    end
    
    // ========== 测试案例3：单个bit不同 ==========
    $display("Test 3: Single bit difference (distance = 1)");
    @(posedge clk);
    census_left = 8'b10101010;
    census_right = 8'b10101011;
    valid_in = 1;
    $display("  Left:  %b", census_left);
    $display("  Right: %b", census_right);
    $display("  XOR:   %b", census_left ^ census_right);
    
    @(posedge clk);
    valid_in = 0;
    
    wait(valid_out == 1);
    @(posedge clk);
    
    $display("  Hamming distance: %d (expected: 1)", hamming_dist);
    if (hamming_dist == 1) begin
        $display("  ✓ PASS\n");
    end else begin
        $display("  ✗ FAIL\n");
    end
    
    // ========== 测试案例4：一半bit不同 ==========
    $display("Test 4: Half bits different (distance = 8)");
    @(posedge clk);
    census_left = 8'b11110000;
    census_right = 8'b00001111;
    valid_in = 1;
    $display("  Left:  %b", census_left);
    $display("  Right: %b", census_right);
    
    @(posedge clk);
    valid_in = 0;
    
    wait(valid_out == 1);
    @(posedge clk);
    
    $display("  Hamming distance: %d (expected: 8)", hamming_dist);
    if (hamming_dist == 8) begin
        $display("  ✓ PASS\n");
    end else begin
        $display("  ✗ FAIL\n");
    end
    
    // ========== 测试案例5：真实场景 ==========
    $display("Test 5: Real scenario from stereo matching");
    @(posedge clk);
    census_left = 8'b01110010;
    census_right = 8'b01010010;
    valid_in = 1;
    $display("  Left:  %b", census_left);
    $display("  Right: %b", census_right);
    $display("  XOR:   %b", census_left ^ census_right);
    
    @(posedge clk);
    valid_in = 0;
    
    wait(valid_out == 1);
    @(posedge clk);
    
    $display("  Hamming distance: %d (expected: 1)", hamming_dist);
    if (hamming_dist == 1) begin
        $display("  ✓ PASS - Good match!\n");
    end else begin
        $display("  ✗ FAIL\n");
    end
    
    // ========== 测试案例6：连续输入测试 ==========
    $display("Test 6: Continuous input stream");
    repeat(10) begin
        @(posedge clk);
        census_left = $random;
        census_right = $random;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(5) @(posedge clk);
        if (valid_out) begin
            $display("  Random test: Left=%b, Right=%b, Distance=%d",
                     census_left, census_right, hamming_dist);
        end
    end
    
    $display("\n=== All tests completed ===\n");
    
    #100;
    $finish;
end

// 监控流水线延迟
integer latency_counter;
reg counting;

always @(posedge clk) begin
    if (valid_in && !counting) begin
        latency_counter <= 0;
        counting <= 1;
    end
    else if (counting && !valid_out) begin
        latency_counter <= latency_counter + 1;
    end
    else if (valid_out && counting) begin
        $display("  [Pipeline latency: %d cycles]", latency_counter);
        counting <= 0;
    end
end

initial begin
    latency_counter = 0;
    counting = 0;
end

endmodule

