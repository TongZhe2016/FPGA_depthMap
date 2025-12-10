# 🚀 快速开始指南

## 1️⃣ 验证Python参考实现（1分钟）

```bash
cd C:\Users\14126\Documents\GitHub\FPGA_depthMap
python census_python_reference.py
```

**输出结果：**
- `Python_test_implementation/disparity_census_3x3.png` - Census视差图
- `Python_test_implementation/disparity_ssd_7x7.png` - SSD对比图
- `Python_test_implementation/left_census_3x3.png` - Census码可视化

---

## 2️⃣ Vivado单元测试（5分钟）

### 打开Vivado项目
```tcl
# 在Vivado TCL Console中执行
cd C:/Users/14126/Documents/GitHub/FPGA_depthMap
open_project FPGA_depthMap_sim/FPGA_depthMap_sim.xpr
```

### 自动运行所有单元测试
```tcl
source run_census_tests.tcl
```

**测试项目：**
- ✅ Census Transform (4个测试)
- ✅ Hamming Distance (5个测试)
- ✅ Window Generator (完整图像验证)

---

## 3️⃣ 生成完整视差图（10-15分钟）

### 方法1：使用Census Transform（推荐）

```tcl
# 确保parameter.v中启用了Census
# `define USE_CENSUS 应该未注释

set_property top tb_disparity_unified [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run -all
```

**输出：** `output.bmp` (使用Census算法)

### 方法2：使用SSD（对比用）

1. 编辑 `parameter.v`：
   ```verilog
   //`define USE_CENSUS    // 注释掉Census
   `define USE_SSD        // 取消注释SSD
   ```

2. 运行仿真：
   ```tcl
   set_property top tb_disparity_unified [get_filesets sim_1]
   update_compile_order -fileset sim_1
   launch_simulation
   run -all
   ```

**输出：** `output.bmp` (使用SSD算法)

---

## 📊 结果对比

运行两次仿真（Census和SSD），然后对比输出：

```
output.bmp (Census)          vs    legacy_ssd/Tsukuba_output_7.bmp (SSD)
```

**Census优势：**
- 光照变化更鲁棒
- 边缘清晰
- 噪声更少

---

## 🔧 修改参数

编辑 `parameter.v` 来调整参数：

```verilog
`define WIDTH  320              // 图像宽度
`define HEIGHT 240              // 图像高度
`define DISPARITY_MIN 4         // 最小视差
`define DISPARITY_MAX 10        // 最大视差
`define WINDOW_SIZE   3         // 窗口大小 (3x3)
```

---

## ⚡ 性能指标

| 指标 | Census | SSD |
|------|--------|-----|
| 仿真时间 | ~12分钟 | ~10分钟 |
| 硬件资源 | 低（无乘法器） | 高（49个乘法器） |
| 输出质量 | 好 | 一般 |
| 光照鲁棒性 | ✅ | ❌ |

---

## 🐛 常见问题

### Q: 找不到hex文件？
**A:** 确保 `parameter.v` 中使用**绝对路径**：
```verilog
`define INPUTFILENAME_L "C:/Users/14126/Documents/GitHub/FPGA_depthMap/Tsukuba_L.hex"
```

### Q: 仿真速度太慢？
**A:** 正常现象，Census计算需要10-15分钟。可以：
- 减小图像尺寸
- 减小视差范围
- 使用更快的电脑

### Q: output.bmp只有一条白线？
**A:** 等待仿真完全结束（`enc_done=1`）再检查输出文件。

### Q: 想使用自己的图像？
**A:** 使用 `imgtohex.ipynb` 将图像转换为hex格式：
```python
jupyter notebook imgtohex.ipynb
```

---

## 📚 更多信息

- **详细文档:** `CENSUS_README.md`
- **算法原理:** Census Transform原理和实现细节
- **SSD存档:** `legacy_ssd/README_LEGACY.md`

---

**准备好了？开始运行吧！** 🎉

