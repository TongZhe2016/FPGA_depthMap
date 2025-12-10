`timescale 1ns/1ps 
/**************************************************************************/
/************** 统一的视差计算Testbench (支持SSD和Census) ******************/
/**************************************************************************/

`include "parameter.v"

module tb_disparity_unified;

//-------------------------------------------------
// Internal Signals
//-------------------------------------------------
reg HCLK, HRESETn;
wire vsync;
wire hsync;
wire [7:0] data_0;
wire [7:0] data_1;
wire enc_done;

//-------------------------------------------------
// 选择算法：在parameter.v中定义USE_CENSUS
//-------------------------------------------------
`ifdef USE_CENSUS
    // 使用Census Transform
    image_read_census 
    #(.INFILE_L(`INPUTFILENAME_L), .INFILE_R(`INPUTFILENAME_R))
    u_image_read_census (
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
    
    initial begin
        $display("\n=== Census Transform Disparity Generation ===");
        $display("Algorithm: Census + Hamming Distance");
        $display("Window: 3x3, Disparity range: 4-10\n");
    end
`else
    // 使用SSD算法
    image_read 
    #(.INFILE_L(`INPUTFILENAME_L), .INFILE_R(`INPUTFILENAME_R))
    u_image_read (
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
    
    initial begin
        $display("\n=== SSD Disparity Generation ===");
        $display("Algorithm: Sum of Squared Differences");
        $display("Window: 7x7, Disparity range: 4-10\n");
    end
`endif

//-------------------------------------------------
// Image Write模块
//-------------------------------------------------
image_write 
#(.INFILE(`OUTPUTFILENAME))
u_image_write (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .hsync(hsync),
    .DATA_WRITE_0(data_0),
    .DATA_WRITE_1(data_1),
    .Write_Done()
);

//-------------------------------------------------
// 时钟生成：50MHz
//-------------------------------------------------
initial begin 
    HCLK = 0;
    forever #10 HCLK = ~HCLK;
end

//-------------------------------------------------
// 复位和控制
//-------------------------------------------------
initial begin
    $display("Starting simulation...");
    $display("Image: 320x240 (%s, %s)", `INPUTFILENAME_L, `INPUTFILENAME_R);
    $display("Output: %s\n", `OUTPUTFILENAME);
    
    HRESETn = 0;
    #25 HRESETn = 1;
    
    // 等待完成
    wait(enc_done == 1'b1);
    
    $display("\n✓ Disparity generation completed!");
    $display("Simulation time: %t", $time);
    
    #1000;
    $finish;
end

//-------------------------------------------------
// 进度监控
//-------------------------------------------------
integer pixel_count;
real start_time;

initial begin
    pixel_count = 0;
    start_time = $realtime;
    
    forever begin
        @(posedge hsync);
        pixel_count = pixel_count + 2;
        
        if(pixel_count % 7680 == 0) begin  // 每10%报告一次
            $display("  Progress: %0d%% (%0d/76800 pixels) - Time: %0t", 
                     (pixel_count * 100) / 76800, pixel_count, $time);
        end
    end
end

//-------------------------------------------------
// 超时保护：30分钟
//-------------------------------------------------
initial begin
    #1800_000_000_000;  // 30分钟 = 1800秒
    $display("\n✗ TIMEOUT: Simulation exceeded 30 minutes");
    $display("Current progress: %0d pixels", pixel_count);
    $finish;
end

endmodule

