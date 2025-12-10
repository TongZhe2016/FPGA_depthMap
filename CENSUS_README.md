# Census Transform立体匹配实现

## 📁 项目结构

### 核心Verilog模块
```
census_transform.v          - Census变换和窗口生成器
hamming_distance.v          - Hamming距离计算（流水线版）
image_read_census.v         - 集成的Census立体匹配模块
```

### Testbench文件
```
tb_census_transform.v       - Census Transform单元测试
tb_hamming_distance.v       - Hamming Distance单元测试
tb_window_generator.v       - Window Generator单元测试
tb_census_disparity.v       - 完整视差图生成测试
```

### Python参考实现
```
census_python_reference.py  - Python版Census算法（用于验证）
```

### 输出结果
```
Python_test_implementation/
  ├─ disparity_census_3x3.png        - Python Census结果
  ├─ disparity_census_3x3_color.jpg  - 伪彩色视差图
  ├─ disparity_ssd_7x7.png           - SSD对比结果
  └─ left_census_3x3.png             - Census码可视化

FPGA_depthMap_sim/.../xsim/
  └─ output_census.bmp               - Verilog仿真输出
```

---

## 🎯 Census Transform算法

### 原理
Census Transform将像素窗口转换为二进制描述符：
- 比较邻域像素和中心像素
- 生成8-bit码（3x3窗口）
- 对光照变化鲁棒

### vs SSD对比

| 特性 | SSD | Census + Hamming |
|------|-----|------------------|
| 光照鲁棒性 | ❌ 敏感 | ✅ 鲁棒 |
| 硬件资源 | 49个乘法器 | 8个比较器 |
| 计算复杂度 | O(W²) | O(W²/8) |
| 流水线化 | 困难 | 容易 |

---

## 🚀 使用方法

### 1. 运行Python验证
```bash
python census_python_reference.py
```
输出：
- `disparity_census_3x3.png` - Census视差图
- `disparity_ssd_7x7.png` - SSD对比图

### 2. Vivado仿真

#### 单元测试
```tcl
# Census Transform测试
set_property top tb_census_transform [get_filesets sim_1]
launch_simulation
run 10us

# Hamming Distance测试
set_property top tb_hamming_distance [get_filesets sim_1]
launch_simulation
run 10us

# Window Generator测试
set_property top tb_window_generator [get_filesets sim_1]
launch_simulation
run 5ms
```

#### 完整视差图生成
```tcl
# 生成视差图
set_property top tb_census_disparity [get_filesets sim_1]
launch_simulation
run -all  # 需要5-15分钟
```

输出：`output_census.bmp`

---

## ✅ 测试结果

### 单元测试（全部通过）
- ✅ Census Transform (4/4)
- ✅ Hamming Distance (5/5)  
- ✅ Window Generator (完整图像验证)

### 性能指标
- **Census窗口**: 3×3 → 8-bit码
- **Hamming流水线**: 4级，延迟4周期
- **Window Generator延迟**: 2像素
- **视差范围**: 4-10像素
- **图像大小**: 320×240

---

## 📊 模块详解

### Census Transform
```verilog
输入：3×3窗口的9个像素
处理：比较8个邻域 >= 中心
输出：8-bit Census码
```

**示例：**
```
窗口:          Census码:
100 120 110    0 1 1
 90 105 130 → 0 X 1 → 0b01110010
 95 100 140    0 0 1
```

### Hamming Distance
```verilog
输入：2个8-bit Census码
处理：XOR + Popcount（树形累加）
输出：4-bit距离值(0-8)
流水线：4级
```

### Window Generator
```verilog
输入：逐像素流式输入
处理：行缓存 + 移位寄存器
输出：3×3滑动窗口（展平为72-bit向量）
延迟：2像素
```

---

## 🔧 技术要点

### 1. 数组展平
Verilog-2001不支持多维数组作为端口：
```verilog
// ❌ 不支持
output reg [7:0] window [0:2][0:2];

// ✅ 正确
output reg [71:0] window_flat;
// 72-bit = 9像素 × 8bit
```

### 2. 流水线valid信号
```verilog
// valid信号只保持1周期！
// 使用wait()等待：
wait(valid_out == 1);
@(posedge clk);
// 此时数据有效
```

### 3. 时序延迟
- Census Transform: 1周期
- Hamming Distance: 4周期  
- Window Generator: 2像素

---

## 📝 已知问题

1. **仿真速度慢**
   - Census计算用function实现，无流水线
   - 解决：综合时硬件会并行化

2. **边界处理简化**
   - 边缘像素未处理Census
   - 改进：添加padding或跳过边缘

3. **固定参数**
   - 窗口大小固定3×3
   - 视差范围固定4-10
   - 改进：参数化设计

---

## 🎓 学习要点

1. **Census Transform原理** - 局部结构描述
2. **Hamming Distance** - 位差异度量
3. **流水线设计** - 提高吞吐量
4. **Verilog数组处理** - 展平技巧
5. **硬件时序** - valid信号管理

---

## 📚 参考资料

- Zabih & Woodfill, "Non-parametric Local Transforms", ECCV 1994
- 原始SSD实现: [FPGA-DepthMap](https://github.com/Archfx/FPGA_depthMap)

---

## 🏆 成果

✅ 完整实现Census Transform算法  
✅ 所有单元测试通过  
✅ Python验证对比  
✅ 硬件友好的流水线设计  
✅ 对光照变化鲁棒  

---

**Created: 2025-12-10**

