`timescale 1ns/1ps
/*****************************************************************************/
/******************** Window Generator Testbench *****************************/
/*****************************************************************************/

module tb_window_generator;

// 参数
parameter WIDTH = 320;
parameter HEIGHT = 240;
parameter WINDOW_SIZE = 3;
parameter PIXEL_WIDTH = 8;

// 时钟和复位
reg clk;
reg rst_n;

// 输入
reg [PIXEL_WIDTH-1:0] pixel_in;
reg pixel_valid;

// 输出
wire [WINDOW_SIZE*WINDOW_SIZE*PIXEL_WIDTH-1:0] window_flat;
wire window_valid;

// 解包窗口（用于显示和验证）
wire [PIXEL_WIDTH-1:0] window [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
genvar gi, gj;
generate
    for (gi = 0; gi < WINDOW_SIZE; gi = gi + 1) begin : row_unpack
        for (gj = 0; gj < WINDOW_SIZE; gj = gj + 1) begin : col_unpack
            assign window[gi][gj] = window_flat[(gi*WINDOW_SIZE + gj + 1)*PIXEL_WIDTH-1 -: PIXEL_WIDTH];
        end
    end
endgenerate

// 实例化待测模块
window_generator #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .WINDOW_SIZE(WINDOW_SIZE),
    .PIXEL_WIDTH(PIXEL_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .pixel_in(pixel_in),
    .pixel_valid(pixel_valid),
    .window_flat(window_flat),
    .window_valid(window_valid)
);

// 时钟生成
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

// 测试图像：简单的渐变图案
integer test_image [0:HEIGHT-1][0:WIDTH-1];
integer row, col;

initial begin
    // 生成测试图像：行号*列号的模式
    for (row = 0; row < HEIGHT; row = row + 1) begin
        for (col = 0; col < WIDTH; col = col + 1) begin
            test_image[row][col] = (row + col) % 256;
        end
    end
end

// 像素计数器
integer pixel_count;
integer current_row, current_col;

// 测试流程
initial begin
    $dumpfile("window_generator.vcd");
    $dumpvars(0, tb_window_generator);
    
    // 初始化
    rst_n = 0;
    pixel_in = 0;
    pixel_valid = 0;
    pixel_count = 0;
    current_row = 0;
    current_col = 0;
    
    #50;
    rst_n = 1;
    #20;
    
    $display("\n=== Window Generator Test ===\n");
    $display("Image size: %dx%d", WIDTH, HEIGHT);
    $display("Window size: %dx%d\n", WINDOW_SIZE, WINDOW_SIZE);
    
    // 输入完整图像流
    for (row = 0; row < HEIGHT; row = row + 1) begin
        for (col = 0; col < WIDTH; col = col + 1) begin
            @(posedge clk);
            pixel_in = test_image[row][col];
            pixel_valid = 1;
            pixel_count = pixel_count + 1;
            current_row = row;
            current_col = col;
            
            // 在特定位置检查窗口
            if (window_valid) begin
                // 第一次窗口有效
                if (pixel_count == WIDTH * WINDOW_SIZE + WINDOW_SIZE) begin
                    $display("✓ Window becomes valid at pixel %d (row=%d, col=%d)",
                             pixel_count, current_row, current_col);
                    $display("  Window center should be at (%d, %d)\n", 
                             WINDOW_SIZE/2, WINDOW_SIZE/2);
                    display_window();
                end
                
                // 测试几个关键位置  
                // 注意：窗口生成有2个像素的延迟
                if (current_row == 10 && current_col == 10) begin
                    $display("Checking window at input position (10, 10):");
                    $display("  (Window center is actually at (%d, %d))", current_row-2, current_col-2);
                    display_window();
                    verify_window(current_row-2, current_col-2);  // 窗口滞后2个像素
                end
                
                if (current_row == HEIGHT/2 && current_col == WIDTH/2) begin
                    $display("Checking window at input position (%d, %d):",
                             current_row, current_col);
                    $display("  (Window center is actually at (%d, %d))", current_row-2, current_col-2);
                    display_window();
                    verify_window(current_row-2, current_col-2);
                end
            end
        end
        
        // 每处理10行报告一次
        if (row % 10 == 0) begin
            $display("  Processing row %d/%d... (windows valid: %d)", 
                     row, HEIGHT, window_valid);
        end
    end
    
    @(posedge clk);
    pixel_valid = 0;
    
    $display("\n✓ Complete image processed (%d pixels)", pixel_count);
    $display("=== Test completed ===\n");
    
    #100;
    $finish;
end

// 显示当前窗口内容
task display_window;
    integer i, j;
    begin
        $display("  Current window:");
        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
            $write("    [");
            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                $write("%3d ", window[i][j]);
            end
            $write("]\n");
        end
    end
endtask

// 验证窗口内容是否正确
task verify_window;
    input integer center_row;
    input integer center_col;
    integer i, j;
    integer expected_value;
    integer actual_value;
    integer errors;
    begin
        errors = 0;
        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                // 计算期望值
                expected_value = test_image[center_row - WINDOW_SIZE/2 + i]
                                          [center_col - WINDOW_SIZE/2 + j];
                actual_value = window[i][j];
                
                if (expected_value !== actual_value) begin
                    $display("  ✗ ERROR at window[%d][%d]: expected %d, got %d",
                             i, j, expected_value, actual_value);
                    errors = errors + 1;
                end
            end
        end
        
        if (errors == 0) begin
            $display("  ✓ Window content verified!\n");
        end else begin
            $display("  ✗ %d errors found\n", errors);
        end
    end
endtask

// 监控窗口有效信号的跳变
reg window_valid_prev;
initial window_valid_prev = 0;

always @(posedge clk) begin
    if (window_valid && !window_valid_prev) begin
        $display("[Time %t] Window generation started", $time);
    end
    window_valid_prev <= window_valid;
end

endmodule

