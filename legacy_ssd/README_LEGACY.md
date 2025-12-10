# Legacy SSD实现（存档）

本目录包含项目最初的**Sum of Squared Differences (SSD)** 算法实现。

## 📁 内容

```
image_read.v            - 原始SSD算法的image_read模块
tb_simulation.v         - 原始testbench
Tsukuba_output_*.bmp    - SSD算法输出的视差图
Disparity_Window_*.pdf  - 窗口仿真文档
```

## ⚠️ 为何弃用

SSD算法存在以下问题：
1. **对光照变化敏感** - 不同光照下效果差
2. **计算量大** - 7×7窗口需要49个乘法器
3. **代码问题** - 使用不可综合的for循环，仿真不准确
4. **硬件资源** - 乘法器消耗多，不适合小型FPGA

## ✅ 新实现

当前项目已升级为 **Census Transform + Hamming Distance** 算法：
- 对光照鲁棒
- 只需8个比较器（无乘法器）
- 完全流水线化
- 硬件友好

详见项目根目录的 `CENSUS_README.md`

---

**保留原因：** 作为对比参考和学习材料

**创建日期：** 2025-12-10

