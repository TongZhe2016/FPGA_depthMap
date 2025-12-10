`timescale 1ns/1ps
/**************************************************************************/
/************ Testbench for Census Transform Disparity *******************/
/**************************************************************************/

`include "parameter.v"

module tb_census_disparity;

// 信号
reg HCLK, HRESETn;
wire vsync;
wire hsync;
wire [7:0] data_0;
wire [7:0] data_1;
wire enc_done;

// 实例化Census版本
image_read_census #(
    .INFILE_L(`INPUTFILENAME_L),
    .INFILE_R(`INPUTFILENAME_R)
) u_image_read_census (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .VSYNC(vsync),
    .HSYNC(hsync),
    .DATA_0_L(data_0),
    .DATA_1_L(data_1),
    .DATA_0_R(),
    .DATA_1_R(),
    .ctrl_done(enc_done)
);

// 实例化输出模块
image_write #(
    .INFILE("output_census.bmp")
) u_image_write (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .hsync(hsync),
    .DATA_WRITE_0(data_0),
    .DATA_WRITE_1(data_1),
    .Write_Done()
);

// 时钟生成：50MHz
initial begin
    HCLK = 0;
    forever #10 HCLK = ~HCLK;
end

// 复位和控制
initial begin
    $display("\n=== Census Transform Disparity Generation ===\n");
    $display("Starting simulation...");
    $display("This will take several minutes to process 320x240 image\n");
    
    HRESETn = 0;
    #25 HRESETn = 1;
    
    // 等待完成
    wait(enc_done == 1'b1);
    
    $display("\n✓ Disparity generation completed!");
    $display("Output file: output_census.bmp");
    $display("Simulation time: %t", $time);
    
    #1000;
    $finish;
end

// 进度监控
integer pixel_count;
initial begin
    pixel_count = 0;
    forever begin
        @(posedge hsync);
        pixel_count = pixel_count + 2;
        if(pixel_count % 3200 == 0) begin
            $display("  Progress: %0d%% (%0d/76800 pixels)", 
                     (pixel_count * 100) / 76800, pixel_count);
        end
    end
end

// 超时保护（500秒 = 500,000,000,000 ps）
initial begin
    #500_000_000_000;  // 500秒
    $display("\n✗ TIMEOUT: Simulation took too long");
    $display("This might indicate a problem with the design");
    $finish;
end

endmodule

