/*****************************************************************************/
/******************** Hamming Distance & Popcount Module *********************/
/*****************************************************************************/
// 简化版：直接计算popcount，不使用复杂的generate块

module hamming_distance
#(
    parameter CENSUS_WIDTH = 8  // 3x3窗口=8bit, 5x5窗口=24bit
)
(
    input wire clk,
    input wire rst_n,
    input wire [CENSUS_WIDTH-1:0] census_left,
    input wire [CENSUS_WIDTH-1:0] census_right,
    input wire valid_in,
    output reg [$clog2(CENSUS_WIDTH+1)-1:0] hamming_dist,
    output reg valid_out
);

// Stage 1: XOR操作
reg [CENSUS_WIDTH-1:0] xor_result;
reg valid_stage1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xor_result <= 0;
        valid_stage1 <= 0;
    end
    else begin
        xor_result <= census_left ^ census_right;
        valid_stage1 <= valid_in;
    end
end

// Stage 2-4: 树形popcount (针对8-bit优化)
// Level 1: 8个bit -> 4个2-bit数
reg [1:0] level1_0, level1_1, level1_2, level1_3;
reg valid_level1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        level1_0 <= 0;
        level1_1 <= 0;
        level1_2 <= 0;
        level1_3 <= 0;
        valid_level1 <= 0;
    end
    else begin
        level1_0 <= xor_result[0] + xor_result[1];
        level1_1 <= xor_result[2] + xor_result[3];
        level1_2 <= xor_result[4] + xor_result[5];
        level1_3 <= xor_result[6] + xor_result[7];
        valid_level1 <= valid_stage1;
    end
end

// Level 2: 4个2-bit -> 2个3-bit
reg [2:0] level2_0, level2_1;
reg valid_level2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        level2_0 <= 0;
        level2_1 <= 0;
        valid_level2 <= 0;
    end
    else begin
        level2_0 <= level1_0 + level1_1;
        level2_1 <= level1_2 + level1_3;
        valid_level2 <= valid_level1;
    end
end

// Level 3: 2个3-bit -> 1个4-bit (最终结果)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hamming_dist <= 0;
        valid_out <= 0;
    end
    else begin
        hamming_dist <= level2_0 + level2_1;
        valid_out <= valid_level2;
    end
end

endmodule

/*****************************************************************************/
/******************** 查找表版本 (备用) **************************************/
/*****************************************************************************/

module hamming_distance_lut
#(
    parameter CENSUS_WIDTH = 8
)
(
    input wire clk,
    input wire rst_n,
    input wire [CENSUS_WIDTH-1:0] census_left,
    input wire [CENSUS_WIDTH-1:0] census_right,
    input wire valid_in,
    output reg [$clog2(CENSUS_WIDTH+1)-1:0] hamming_dist,
    output reg valid_out
);

// XOR + popcount (组合逻辑)
wire [CENSUS_WIDTH-1:0] xor_result;
assign xor_result = census_left ^ census_right;

// Popcount函数
function automatic [$clog2(CENSUS_WIDTH+1)-1:0] popcount;
    input [CENSUS_WIDTH-1:0] bits;
    integer i;
    begin
        popcount = 0;
        for (i = 0; i < CENSUS_WIDTH; i = i + 1) begin
            popcount = popcount + bits[i];
        end
    end
endfunction

// 寄存器输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hamming_dist <= 0;
        valid_out <= 0;
    end
    else begin
        hamming_dist <= popcount(xor_result);
        valid_out <= valid_in;
    end
end

endmodule

