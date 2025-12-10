`timescale 1ns/1ps
/*****************************************************************************/
/******************** Census Transform Testbench *****************************/
/*****************************************************************************/

module tb_census_transform;

// 时钟和复位
reg clk;
reg rst_n;

// 输入
reg [7:0] center_pixel;
reg [7:0] window_pixels [0:7];  // 3x3窗口，去掉中心=8个像素（内部使用）
reg [63:0] window_pixels_flat;  // 8个像素 * 8bit = 64bit

// 输出
wire [7:0] census_code;
wire valid;

// 将数组展平为向量
integer k;
always @(*) begin
    for (k = 0; k < 8; k = k + 1) begin
        window_pixels_flat[(k+1)*8-1 -: 8] = window_pixels[k];
    end
end

// 实例化待测模块
census_transform #(
    .WINDOW_SIZE(3),
    .BIT_WIDTH(8)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .center_pixel(center_pixel),
    .window_pixels_flat(window_pixels_flat),
    .census_code(census_code),
    .valid(valid)
);

// 时钟生成：50MHz (20ns周期)
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

// 测试用例
initial begin
    // 初始化波形文件
    $dumpfile("census_transform.vcd");
    $dumpvars(0, tb_census_transform);
    
    // 复位
    rst_n = 0;
    center_pixel = 0;
    window_pixels[0] = 0;
    window_pixels[1] = 0;
    window_pixels[2] = 0;
    window_pixels[3] = 0;
    window_pixels[4] = 0;
    window_pixels[5] = 0;
    window_pixels[6] = 0;
    window_pixels[7] = 0;
    
    #50;
    rst_n = 1;
    #20;
    
    $display("\n=== Census Transform Test Cases ===\n");
    
    // ========== 测试案例1：均匀区域 ==========
    $display("Test 1: Uniform region (all pixels = 100)");
    center_pixel = 100;
    window_pixels[0] = 100;
    window_pixels[1] = 100;
    window_pixels[2] = 100;
    window_pixels[3] = 100;
    window_pixels[4] = 100;
    window_pixels[5] = 100;
    window_pixels[6] = 100;
    window_pixels[7] = 100;
    
    @(posedge clk);  // 输入数据
    @(posedge clk);  // 等待Census计算
    @(posedge clk);  // 再等一个周期确保输出稳定
    
    if (valid) begin
        $display("  Center: %d", center_pixel);
        $display("  Census: %b (expected: 11111111)", census_code);
        if (census_code == 8'b11111111) begin
            $display("  ✓ PASS\n");
        end else begin
            $display("  ✗ FAIL (got %b, timing issue)\n", census_code);
        end
    end
    
    // ========== 测试案例2：边缘检测 ==========
    $display("Test 2: Edge detection");
    center_pixel = 100;
    window_pixels[0] = 50;   // 左上角较暗
    window_pixels[1] = 50;
    window_pixels[2] = 50;
    window_pixels[3] = 50;
    window_pixels[4] = 150;  // 右下角较亮
    window_pixels[5] = 150;
    window_pixels[6] = 150;
    window_pixels[7] = 150;
    
    @(posedge clk);
    @(posedge clk);
    
    if (valid) begin
        $display("  Center: %d", center_pixel);
        $display("  Window: [%d %d %d] [%d X %d] [%d %d %d]", 
                 window_pixels[0], window_pixels[1], window_pixels[2],
                 window_pixels[3], window_pixels[4],
                 window_pixels[5], window_pixels[6], window_pixels[7]);
        $display("  Census: %b (expected: 11110000)", census_code);
        if (census_code == 8'b11110000) begin
            $display("  ✓ PASS\n");
        end else begin
            $display("  ✗ FAIL\n");
        end
    end
    
    // ========== 测试案例3：真实场景（从Python获取）==========
    $display("Test 3: Real scenario from Tsukuba image");
    center_pixel = 105;
    window_pixels[0] = 100;
    window_pixels[1] = 120;
    window_pixels[2] = 110;
    window_pixels[3] = 90;
    window_pixels[4] = 130;
    window_pixels[5] = 95;
    window_pixels[6] = 100;
    window_pixels[7] = 140;
    
    @(posedge clk);
    @(posedge clk);
    
    if (valid) begin
        $display("  Center: %d", center_pixel);
        $display("  Census: %b", census_code);
        $display("  Each bit: [%d %d %d %d %d %d %d %d]",
                 census_code[0], census_code[1], census_code[2], census_code[3],
                 census_code[4], census_code[5], census_code[6], census_code[7]);
        $display("  ✓ Real data processed\n");
    end
    
    // ========== 测试案例4：极端值 ==========
    $display("Test 4: Extreme values");
    center_pixel = 0;
    window_pixels[0] = 255;
    window_pixels[1] = 255;
    window_pixels[2] = 255;
    window_pixels[3] = 255;
    window_pixels[4] = 255;
    window_pixels[5] = 255;
    window_pixels[6] = 255;
    window_pixels[7] = 255;
    
    @(posedge clk);
    @(posedge clk);
    
    if (valid) begin
        $display("  Center: %d (minimum)", center_pixel);
        $display("  Census: %b (expected: 11111111 - all neighbors brighter)", census_code);
        if (census_code == 8'b11111111) begin
            $display("  ✓ PASS\n");
        end else begin
            $display("  ✗ FAIL\n");
        end
    end
    
    $display("=== All tests completed ===\n");
    
    #100;
    $finish;
end

// 监控输出
always @(posedge clk) begin
    if (valid) begin
        $display("[Time %t] Census code generated: %b", $time, census_code);
    end
end

endmodule

