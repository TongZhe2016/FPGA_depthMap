/*****************************************************************************/
/******************** Census-based Stereo Matching Module ********************/
/*****************************************************************************/
// 使用Census Transform + Hamming Distance替代SSD
// 完整的视差计算流水线

module census_stereo_matching
#(
    parameter WIDTH = 320,
    parameter HEIGHT = 240,
    parameter WINDOW_SIZE = 3,      // Census窗口大小：3x3
    parameter PIXEL_WIDTH = 8,
    parameter MAX_DISPARITY = 10,   // 最大视差搜索范围
    parameter MIN_DISPARITY = 4     // 最小视差
)
(
    input wire clk,
    input wire rst_n,
    
    // 左右图像输入（逐像素流式输入）
    input wire [PIXEL_WIDTH-1:0] left_pixel,
    input wire [PIXEL_WIDTH-1:0] right_pixel,
    input wire pixel_valid,
    
    // 视差输出
    output reg [7:0] disparity_out,
    output reg disparity_valid
);

localparam CENSUS_WIDTH = (WINDOW_SIZE * WINDOW_SIZE - 1);
localparam DISPARITY_BITS = $clog2(MAX_DISPARITY + 1);

// Stage 1: 窗口生成
wire [PIXEL_WIDTH-1:0] left_window [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
wire [PIXEL_WIDTH-1:0] right_window [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
wire left_window_valid, right_window_valid;

window_generator #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .WINDOW_SIZE(WINDOW_SIZE),
    .PIXEL_WIDTH(PIXEL_WIDTH)
) left_win_gen (
    .clk(clk),
    .rst_n(rst_n),
    .pixel_in(left_pixel),
    .pixel_valid(pixel_valid),
    .window(left_window),
    .window_valid(left_window_valid)
);

window_generator #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .WINDOW_SIZE(WINDOW_SIZE),
    .PIXEL_WIDTH(PIXEL_WIDTH)
) right_win_gen (
    .clk(clk),
    .rst_n(rst_n),
    .pixel_in(right_pixel),
    .pixel_valid(pixel_valid),
    .window(right_window),
    .window_valid(right_window_valid)
);

// Stage 2: Census变换
// 提取窗口中心像素和邻域
wire [PIXEL_WIDTH-1:0] left_center, right_center;
wire [PIXEL_WIDTH-1:0] left_neighbors [0:CENSUS_WIDTH-1];
wire [PIXEL_WIDTH-1:0] right_neighbors [0:CENSUS_WIDTH-1];

assign left_center = left_window[WINDOW_SIZE/2][WINDOW_SIZE/2];
assign right_center = right_window[WINDOW_SIZE/2][WINDOW_SIZE/2];

// 展开邻域像素（跳过中心）
integer row, col, idx;
always @(*) begin
    idx = 0;
    for (row = 0; row < WINDOW_SIZE; row = row + 1) begin
        for (col = 0; col < WINDOW_SIZE; col = col + 1) begin
            if (!(row == WINDOW_SIZE/2 && col == WINDOW_SIZE/2)) begin
                left_neighbors[idx] = left_window[row][col];
                right_neighbors[idx] = right_window[row][col];
                idx = idx + 1;
            end
        end
    end
end

wire [CENSUS_WIDTH-1:0] left_census, right_census;
wire census_valid;

census_transform #(
    .WINDOW_SIZE(WINDOW_SIZE),
    .BIT_WIDTH(PIXEL_WIDTH)
) left_census_gen (
    .clk(clk),
    .rst_n(rst_n),
    .center_pixel(left_center),
    .window_pixels(left_neighbors),
    .census_code(left_census),
    .valid(census_valid)
);

census_transform #(
    .WINDOW_SIZE(WINDOW_SIZE),
    .BIT_WIDTH(PIXEL_WIDTH)
) right_census_gen (
    .clk(clk),
    .rst_n(rst_n),
    .center_pixel(right_center),
    .window_pixels(right_neighbors),
    .census_code(right_census),
    .valid()  // 只用left的valid信号
);

// Stage 3: 视差搜索 + Hamming距离计算
// 需要缓存右图的Census码以便进行视差搜索
reg [CENSUS_WIDTH-1:0] right_census_buffer [0:WIDTH-1];
reg [9:0] pixel_col_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_col_counter <= 0;
    end
    else if (census_valid) begin
        // 缓存右图Census码
        right_census_buffer[pixel_col_counter] <= right_census;
        
        if (pixel_col_counter == WIDTH - 1) begin
            pixel_col_counter <= 0;
        end
        else begin
            pixel_col_counter <= pixel_col_counter + 1;
        end
    end
end

// 视差搜索状态机
localparam ST_IDLE = 2'b00;
localparam ST_SEARCH = 2'b01;
localparam ST_DONE = 2'b10;

reg [1:0] search_state;
reg [DISPARITY_BITS-1:0] current_disparity;
reg [DISPARITY_BITS-1:0] best_disparity;
reg [$clog2(CENSUS_WIDTH+1)-1:0] min_hamming;
reg [$clog2(CENSUS_WIDTH+1)-1:0] current_hamming;
wire hamming_valid;

// Hamming距离计算器
hamming_distance #(
    .CENSUS_WIDTH(CENSUS_WIDTH)
) hamming_calc (
    .clk(clk),
    .rst_n(rst_n),
    .census_left(left_census),
    .census_right(right_census_buffer[pixel_col_counter - current_disparity]),
    .valid_in(search_state == ST_SEARCH),
    .hamming_dist(current_hamming),
    .valid_out(hamming_valid)
);

// 视差搜索逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        search_state <= ST_IDLE;
        current_disparity <= MIN_DISPARITY;
        best_disparity <= 0;
        min_hamming <= {$clog2(CENSUS_WIDTH+1){1'b1}};  // 最大值
        disparity_out <= 0;
        disparity_valid <= 0;
    end
    else begin
        case (search_state)
            ST_IDLE: begin
                if (census_valid && pixel_col_counter >= MAX_DISPARITY) begin
                    // 只处理有足够视差搜索空间的像素
                    search_state <= ST_SEARCH;
                    current_disparity <= MIN_DISPARITY;
                    min_hamming <= {$clog2(CENSUS_WIDTH+1){1'b1}};
                end
                disparity_valid <= 0;
            end
            
            ST_SEARCH: begin
                if (hamming_valid) begin
                    // 比较并更新最小Hamming距离
                    if (current_hamming < min_hamming) begin
                        min_hamming <= current_hamming;
                        best_disparity <= current_disparity;
                    end
                    
                    // 继续搜索或结束
                    if (current_disparity == MAX_DISPARITY) begin
                        search_state <= ST_DONE;
                    end
                    else begin
                        current_disparity <= current_disparity + 1;
                    end
                end
            end
            
            ST_DONE: begin
                // 输出视差值（归一化到0-255）
                disparity_out <= best_disparity * (255 / MAX_DISPARITY);
                disparity_valid <= 1'b1;
                search_state <= ST_IDLE;
            end
            
            default: search_state <= ST_IDLE;
        endcase
    end
end

endmodule

