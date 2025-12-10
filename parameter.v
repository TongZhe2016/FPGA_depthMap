/**************************************************************************/
/*************************** Definition file ******************************/
/**************************************************************************/

// 输入输出文件路径（使用绝对路径避免Vivado找不到文件）
`define INPUTFILENAME_L		 "C:/Users/14126/Documents/GitHub/FPGA_depthMap/Tsukuba_L.hex"
`define INPUTFILENAME_R		 "C:/Users/14126/Documents/GitHub/FPGA_depthMap/Tsukuba_R.hex"
`define OUTPUTFILENAME		 "output.bmp"

/**************************************************************************/
// 算法选择：取消注释以启用Census Transform，注释掉则使用SSD算法
/**************************************************************************/
`define USE_CENSUS              // 使用Census + Hamming Distance
//`define USE_SSD               // 使用Sum of Squared Differences

// 图像参数
`define WIDTH  320
`define HEIGHT 240

// 视差参数
`define DISPARITY_MIN 4
`define DISPARITY_MAX 10
`define WINDOW_SIZE   3         // Census窗口大小 (3x3) 
