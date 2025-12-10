/******************************************************************************/
/********** Census Transform版本的视差计算 (替代SSD) *************************/
/******************************************************************************/
`include "parameter.v"

module image_read_census
#(
  parameter WIDTH = 320,
            HEIGHT = 240,
            INFILE_L = "Tsukuba_L.hex",
            INFILE_R = "Tsukuba_R.hex",
            START_UP_DELAY = 100,
            HSYNC_DELAY = 160
)
(
    input HCLK,
    input HRESETn,
    output VSYNC,
    output reg HSYNC,
    output reg [7:0] DATA_0_L,
    output reg [7:0] DATA_1_L,
    output reg [7:0] DATA_0_R,
    output reg [7:0] DATA_1_R,
    output ctrl_done
);

// 参数
parameter sizeOfWidth = 8;
parameter sizeOfLengthReal = 76800;

// FSM状态
localparam ST_IDLE = 2'b00,
           ST_VSYNC = 2'b01,
           ST_HSYNC = 2'b10,
           ST_DATA = 2'b11;

reg [1:0] cstate, nstate;
reg start;
reg HRESETn_d;
reg ctrl_vsync_run;
reg [8:0] ctrl_vsync_cnt;
reg ctrl_hsync_run;
reg [8:0] ctrl_hsync_cnt;
reg ctrl_data_run;

// 图像存储
reg [7:0] total_memory_L [0:sizeOfLengthReal-1];
reg [7:0] total_memory_R [0:sizeOfLengthReal-1];
integer temp_BMP_L [0:WIDTH*HEIGHT-1];
integer temp_BMP_R [0:WIDTH*HEIGHT-1];
integer org_L [0:WIDTH*HEIGHT-1];
integer org_R [0:WIDTH*HEIGHT-1];

integer i, j;
reg [8:0] row;
reg [8:0] col;
reg [18:0] data_count;

// Census参数
localparam WINDOW_SIZE = 3;
localparam CENSUS_BITS = 8;  // 3x3-1 = 8
localparam MIN_OFFSET = 4;
localparam MAX_OFFSET = 10;

// Census计算信号
reg [CENSUS_BITS-1:0] left_census, right_census;
reg [3:0] hamming_dist;
reg [4:0] offset;
reg [4:0] best_offset_0, best_offset_1;
reg [3:0] min_hamming_0, min_hamming_1;
reg offsetfound;
integer x, y;

//-------------------------------------------------
// 读取图像文件
//-------------------------------------------------
initial begin
    $readmemh(INFILE_L, total_memory_L, 0, sizeOfLengthReal-1);
    $readmemh(INFILE_R, total_memory_R, 0, sizeOfLengthReal-1);
end

always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT; i=i+1) begin
            temp_BMP_L[i] = total_memory_L[i];
            temp_BMP_R[i] = total_memory_R[i];
        end
        
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_L[WIDTH*i+j] = temp_BMP_L[WIDTH*i+j];
                org_R[WIDTH*i+j] = temp_BMP_R[WIDTH*i+j];
            end
        end
    end
end

//-------------------------------------------------
// 启动信号
//-------------------------------------------------
always@(posedge HCLK, negedge HRESETn) begin
    if(!HRESETn) begin
        start <= 0;
        HRESETn_d <= 0;
    end
    else begin
        HRESETn_d <= HRESETn;
        if(HRESETn == 1'b1 && HRESETn_d == 1'b0)
            start <= 1'b1;
        else
            start <= 1'b0;
    end
end

//-------------------------------------------------
// FSM
//-------------------------------------------------
always@(posedge HCLK, negedge HRESETn) begin
    if(~HRESETn) begin
        cstate <= ST_IDLE;
    end
    else begin
        cstate <= nstate;
    end
end

always @(*) begin
    case(cstate)
        ST_IDLE: begin
            if(start)
                nstate = ST_VSYNC;
            else
                nstate = ST_IDLE;
        end
        ST_VSYNC: begin
            if(ctrl_vsync_cnt == START_UP_DELAY)
                nstate = ST_HSYNC;
            else
                nstate = ST_VSYNC;
        end
        ST_HSYNC: begin
            if(ctrl_hsync_cnt == HSYNC_DELAY)
                nstate = ST_DATA;
            else
                nstate = ST_HSYNC;
        end
        ST_DATA: begin
            if(ctrl_done)
                nstate = ST_IDLE;
            else begin
                if(col == WIDTH - 2)
                    nstate = ST_HSYNC;
                else
                    nstate = ST_DATA;
            end
        end
    endcase
end

always @(*) begin
    ctrl_vsync_run = 0;
    ctrl_hsync_run = 0;
    ctrl_data_run = 0;
    case(cstate)
        ST_VSYNC: begin ctrl_vsync_run = 1; end
        ST_HSYNC: begin ctrl_hsync_run = 1; end
        ST_DATA:  begin ctrl_data_run = 1; end
    endcase
end

always@(posedge HCLK, negedge HRESETn) begin
    if(~HRESETn) begin
        ctrl_vsync_cnt <= 0;
        ctrl_hsync_cnt <= 0;
    end
    else begin
        if(ctrl_vsync_run)
            ctrl_vsync_cnt <= ctrl_vsync_cnt + 1;
        else
            ctrl_vsync_cnt <= 0;
            
        if(ctrl_hsync_run)
            ctrl_hsync_cnt <= ctrl_hsync_cnt + 1;
        else
            ctrl_hsync_cnt <= 0;
    end
end

//-------------------------------------------------
// Census Transform计算函数
//-------------------------------------------------
function [CENSUS_BITS-1:0] compute_census;
    input integer center_row, center_col;
    input integer is_left;  // 1=left, 0=right
    integer cx, cy, idx;
    integer center_val, neighbor_val;
    begin
        idx = 0;
        if(is_left)
            center_val = org_L[center_row * WIDTH + center_col];
        else
            center_val = org_R[center_row * WIDTH + center_col];
            
        compute_census = 0;
        for(cx = -1; cx <= 1; cx = cx + 1) begin
            for(cy = -1; cy <= 1; cy = cy + 1) begin
                if(!(cx == 0 && cy == 0)) begin
                    if(is_left)
                        neighbor_val = org_L[(center_row + cx) * WIDTH + (center_col + cy)];
                    else
                        neighbor_val = org_R[(center_row + cx) * WIDTH + (center_col + cy)];
                    
                    if(neighbor_val >= center_val)
                        compute_census[idx] = 1;
                    idx = idx + 1;
                end
            end
        end
    end
endfunction

//-------------------------------------------------
// Hamming Distance计算函数
//-------------------------------------------------
function [3:0] compute_hamming;
    input [CENSUS_BITS-1:0] code1, code2;
    integer i;
    reg [CENSUS_BITS-1:0] xor_result;
    begin
        xor_result = code1 ^ code2;
        compute_hamming = 0;
        for(i = 0; i < CENSUS_BITS; i = i + 1) begin
            compute_hamming = compute_hamming + xor_result[i];
        end
    end
endfunction

//-------------------------------------------------
// 像素处理和视差搜索
//-------------------------------------------------
always@(posedge HCLK, negedge HRESETn) begin
    if(~HRESETn) begin
        row <= 0;
        col <= 0;
        offset <= MIN_OFFSET;
        offsetfound <= 0;
        best_offset_0 <= 0;
        best_offset_1 <= 0;
        min_hamming_0 <= 15;
        min_hamming_1 <= 15;
    end
    else begin
        if(ctrl_data_run) begin
            if(offsetfound == 1) begin
                // 完成当前像素，移动到下一对
                if(col == WIDTH - 2) begin
                    col <= 0;
                    row <= row + 1;
                end
                else begin
                    col <= col + 2;
                end
                offsetfound <= 0;
                offset <= MIN_OFFSET;
                min_hamming_0 <= 15;
                min_hamming_1 <= 15;
                best_offset_0 <= 0;
                best_offset_1 <= 0;
            end
            else begin
                // 视差搜索
                if(row >= 1 && row < HEIGHT-1 && col >= MAX_OFFSET) begin
                    // 计算Census码
                    left_census = compute_census(row, col, 1);
                    right_census = compute_census(row, col-offset, 0);
                    hamming_dist = compute_hamming(left_census, right_census);
                    
                    // 更新最小值（像素0）
                    if(hamming_dist < min_hamming_0) begin
                        min_hamming_0 <= hamming_dist;
                        best_offset_0 <= offset;
                    end
                    
                    // 像素1
                    if(col + 1 < WIDTH) begin
                        left_census = compute_census(row, col+1, 1);
                        right_census = compute_census(row, col+1-offset, 0);
                        hamming_dist = compute_hamming(left_census, right_census);
                        
                        if(hamming_dist < min_hamming_1) begin
                            min_hamming_1 <= hamming_dist;
                            best_offset_1 <= offset;
                        end
                    end
                end
                
                // 继续或完成
                if(offset == MAX_OFFSET) begin
                    offsetfound <= 1;
                end
                else begin
                    offset <= offset + 1;
                end
            end
        end
    end
end

// 输出视差值
always@(posedge HCLK) begin
    if(offsetfound) begin
        DATA_0_L <= best_offset_0 * (255 / MAX_OFFSET);
        DATA_1_L <= best_offset_1 * (255 / MAX_OFFSET);
    end
end

// HSYNC信号
reg hsync_reg;
always @(posedge HCLK, negedge HRESETn) begin
    if(~HRESETn) begin
        hsync_reg <= 1'b0;
    end
    else begin
        hsync_reg <= offsetfound;
    end
end

always @(*) begin
    if(ctrl_data_run && hsync_reg) begin
        HSYNC = 1'b1;
    end
    else begin
        HSYNC = 1'b0;
    end
end

// 数据计数
always@(posedge HCLK, negedge HRESETn) begin
    if(~HRESETn) begin
        data_count <= 0;
    end
    else begin
        if(ctrl_data_run && offsetfound) begin
            data_count <= data_count + 2;
        end
    end
end

assign VSYNC = ctrl_vsync_run;
assign ctrl_done = (data_count >= WIDTH*HEIGHT) ? 1'b1 : 1'b0;

endmodule

