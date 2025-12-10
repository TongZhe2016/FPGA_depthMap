/*****************************************************************************/
/******************** Census Transform Module ********************************/
/*****************************************************************************/
// 实现3x3或5x5窗口的Census变换
// 输入：窗口内的像素值（展平为单个向量）
// 输出：Census二进制描述符

module census_transform
#(
    parameter WINDOW_SIZE = 3,  // 3x3 or 5x5
    parameter BIT_WIDTH = 8     // 像素位宽
)
(
    input wire clk,
    input wire rst_n,
    input wire [BIT_WIDTH-1:0] center_pixel,
    // 展平的窗口像素：[pixel0, pixel1, ..., pixel7] for 3x3 (不包括中心)
    input wire [(WINDOW_SIZE*WINDOW_SIZE-1)*BIT_WIDTH-1:0] window_pixels_flat,
    output reg [WINDOW_SIZE*WINDOW_SIZE-2:0] census_code,
    output reg valid
);

integer i;
wire [BIT_WIDTH-1:0] pixel_array [0:WINDOW_SIZE*WINDOW_SIZE-2];

// 解包展平的向量到数组（仅在内部使用）
genvar g;
generate
    for (g = 0; g < WINDOW_SIZE*WINDOW_SIZE-1; g = g + 1) begin : unpack
        assign pixel_array[g] = window_pixels_flat[(g+1)*BIT_WIDTH-1 : g*BIT_WIDTH];
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        census_code <= 0;
        valid <= 0;
    end
    else begin
        // Census变换：比较邻域像素和中心像素
        for (i = 0; i < WINDOW_SIZE*WINDOW_SIZE-1; i = i + 1) begin
            census_code[i] <= (pixel_array[i] >= center_pixel);
        end
        valid <= 1'b1;
    end
end

endmodule

/*****************************************************************************/
/******************** 窗口生成模块 (Register-based) *************************/
/*****************************************************************************/
// 使用行缓存(line buffer)和移位寄存器生成滑动窗口
// 输出窗口展平为单个向量

module window_generator
#(
    parameter WIDTH = 320,
    parameter HEIGHT = 240,
    parameter WINDOW_SIZE = 3,
    parameter PIXEL_WIDTH = 8
)
(
    input wire clk,
    input wire rst_n,
    input wire [PIXEL_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    // 展平的窗口输出：[row0_col0, row0_col1, ..., row2_col2] for 3x3
    output reg [WINDOW_SIZE*WINDOW_SIZE*PIXEL_WIDTH-1:0] window_flat,
    output reg window_valid
);

// 行缓存：存储前(WINDOW_SIZE-1)行
reg [PIXEL_WIDTH-1:0] line_buffer [0:WINDOW_SIZE-2][0:WIDTH-1];

// 移位寄存器：当前行的窗口（内部使用2D数组）
reg [PIXEL_WIDTH-1:0] shift_reg [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];

integer row_idx, col_idx;
reg [9:0] col_counter;
reg [8:0] row_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        col_counter <= 0;
        row_counter <= 0;
        window_valid <= 0;
        window_flat <= 0;
    end
    else if (pixel_valid) begin
        // 移位操作：新像素从右侧进入
        for (row_idx = 0; row_idx < WINDOW_SIZE; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < WINDOW_SIZE-1; col_idx = col_idx + 1) begin
                shift_reg[row_idx][col_idx] <= shift_reg[row_idx][col_idx+1];
            end
        end
        
        // 从行缓存和新像素更新最右列
        for (row_idx = 0; row_idx < WINDOW_SIZE-1; row_idx = row_idx + 1) begin
            shift_reg[row_idx][WINDOW_SIZE-1] <= line_buffer[row_idx][col_counter];
        end
        shift_reg[WINDOW_SIZE-1][WINDOW_SIZE-1] <= pixel_in;
        
        // 更新行缓存
        for (row_idx = 0; row_idx < WINDOW_SIZE-2; row_idx = row_idx + 1) begin
            line_buffer[row_idx][col_counter] <= line_buffer[row_idx+1][col_counter];
        end
        if (WINDOW_SIZE > 1) begin
            line_buffer[WINDOW_SIZE-2][col_counter] <= pixel_in;
        end
        
        // 计数器更新
        if (col_counter == WIDTH-1) begin
            col_counter <= 0;
            row_counter <= row_counter + 1;
        end
        else begin
            col_counter <= col_counter + 1;
        end
        
        // 窗口有效信号：至少有WINDOW_SIZE行和列已处理
        if (row_counter >= WINDOW_SIZE-1 && col_counter >= WINDOW_SIZE-1) begin
            window_valid <= 1'b1;
            // 展平窗口到输出向量
            for (row_idx = 0; row_idx < WINDOW_SIZE; row_idx = row_idx + 1) begin
                for (col_idx = 0; col_idx < WINDOW_SIZE; col_idx = col_idx + 1) begin
                    window_flat[(row_idx*WINDOW_SIZE + col_idx + 1)*PIXEL_WIDTH-1 -: PIXEL_WIDTH] 
                        <= shift_reg[row_idx][col_idx];
                end
            end
        end
        else begin
            window_valid <= 1'b0;
        end
    end
end

endmodule

