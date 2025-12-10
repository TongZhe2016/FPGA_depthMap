/*****************************************************************************/
/******************** Hamming Distance & Popcount Module *********************/
/*****************************************************************************/
// 完全流水线化的汉明距离计算
// 使用树形加法器实现高效的popcount

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

// Stage 2-N: 树形累加器计算popcount
// 使用并行的两两相加，然后递归
generate
    if (CENSUS_WIDTH == 8) begin : popcount_8bit
        // 3x3窗口：8-bit popcount
        // Level 1: 8个bit -> 4个2-bit数
        reg [1:0] level1 [0:3];
        reg valid_level1;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_level1 <= 0;
            end
            else begin
                level1[0] <= xor_result[0] + xor_result[1];
                level1[1] <= xor_result[2] + xor_result[3];
                level1[2] <= xor_result[4] + xor_result[5];
                level1[3] <= xor_result[6] + xor_result[7];
                valid_level1 <= valid_stage1;
            end
        end
        
        // Level 2: 4个2-bit -> 2个3-bit
        reg [2:0] level2 [0:1];
        reg valid_level2;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_level2 <= 0;
            end
            else begin
                level2[0] <= level1[0] + level1[1];
                level2[1] <= level1[2] + level1[3];
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
                hamming_dist <= level2[0] + level2[1];
                valid_out <= valid_level2;
            end
        end
        
    end
    else if (CENSUS_WIDTH == 24) begin : popcount_24bit
        // 5x5窗口：24-bit popcount
        // Level 1: 24个bit -> 12个2-bit数
        reg [1:0] level1 [0:11];
        reg valid_level1;
        integer i;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_level1 <= 0;
            end
            else begin
                for (i = 0; i < 12; i = i + 1) begin
                    level1[i] <= xor_result[2*i] + xor_result[2*i+1];
                end
                valid_level1 <= valid_stage1;
            end
        end
        
        // Level 2: 12个2-bit -> 6个3-bit
        reg [2:0] level2 [0:5];
        reg valid_level2;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_level2 <= 0;
            end
            else begin
                for (i = 0; i < 6; i = i + 1) begin
                    level2[i] <= level1[2*i] + level1[2*i+1];
                end
                valid_level2 <= valid_level1;
            end
        end
        
        // Level 3: 6个3-bit -> 3个4-bit
        reg [3:0] level3 [0:2];
        reg valid_level3;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_level3 <= 0;
            end
            else begin
                for (i = 0; i < 3; i = i + 1) begin
                    level3[i] <= level2[2*i] + level2[2*i+1];
                end
                valid_level3 <= valid_level2;
            end
        end
        
        // Level 4: 3个4-bit -> 1个5-bit (最终结果)
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hamming_dist <= 0;
                valid_out <= 0;
            end
            else begin
                hamming_dist <= level3[0] + level3[1] + level3[2];
                valid_out <= valid_level3;
            end
        end
    end
endgenerate

endmodule

/*****************************************************************************/
/******************** 查找表(LUT)版本的Popcount (替代方案) *******************/
/*****************************************************************************/
// 对于资源受限的FPGA，可以用LUT实现
// 但流水线深度浅，可能时序更紧张

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

// XOR + LUT查表
wire [CENSUS_WIDTH-1:0] xor_result;
assign xor_result = census_left ^ census_right;

// Popcount查找表（仅适用于8-bit）
function automatic [3:0] popcount_8;
    input [7:0] bits;
    integer i;
    begin
        popcount_8 = 0;
        for (i = 0; i < 8; i = i + 1) begin
            popcount_8 = popcount_8 + bits[i];
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hamming_dist <= 0;
        valid_out <= 0;
    end
    else begin
        hamming_dist <= popcount_8(xor_result);
        valid_out <= valid_in;
    end
end

endmodule

