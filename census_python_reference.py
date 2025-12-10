#!/usr/bin/env python3
"""
Census Transform + Hamming Distance 立体匹配 - Python参考实现
用于验证Verilog实现的正确性
"""

import numpy as np
import cv2
import matplotlib.pyplot as plt
from pathlib import Path

def census_transform_3x3(img):
    """
    3x3 Census变换
    
    Args:
        img: 灰度图像 (H, W)
    
    Returns:
        census: Census码图像 (H, W), dtype=uint8 (8-bit)
    """
    h, w = img.shape
    census = np.zeros((h, w), dtype=np.uint8)
    
    for i in range(1, h-1):
        for j in range(1, w-1):
            center = img[i, j]
            code = 0
            bit = 0
            
            # 遍历3x3窗口（跳过中心）
            for di in [-1, 0, 1]:
                for dj in [-1, 0, 1]:
                    if di == 0 and dj == 0:
                        continue  # 跳过中心像素
                    
                    # 比较邻域像素与中心像素
                    if img[i+di, j+dj] >= center:
                        code |= (1 << bit)
                    bit += 1
            
            census[i, j] = code
    
    return census

def census_transform_5x5(img):
    """
    5x5 Census变换
    
    Returns:
        census: Census码图像 (H, W), dtype=uint32 (24-bit)
    """
    h, w = img.shape
    census = np.zeros((h, w), dtype=np.uint32)
    
    for i in range(2, h-2):
        for j in range(2, w-2):
            center = img[i, j]
            code = 0
            bit = 0
            
            # 遍历5x5窗口（跳过中心）
            for di in [-2, -1, 0, 1, 2]:
                for dj in [-2, -1, 0, 1, 2]:
                    if di == 0 and dj == 0:
                        continue
                    
                    if img[i+di, j+dj] >= center:
                        code |= (1 << bit)
                    bit += 1
            
            census[i, j] = code
    
    return census

def hamming_distance(a, b):
    """计算两个数的汉明距离"""
    xor = int(a) ^ int(b)
    return bin(xor).count('1')

def hamming_distance_vectorized(a, b):
    """向量化的汉明距离计算"""
    xor = np.bitwise_xor(a, b)
    # 使用numpy的unpackbits会更快，但这里保持简单
    return np.array([bin(x).count('1') for x in xor.flat]).reshape(a.shape)

def census_stereo_matching(left, right, window_size=3, min_disp=4, max_disp=10):
    """
    Census立体匹配
    
    Args:
        left: 左图像
        right: 右图像
        window_size: Census窗口大小 (3 or 5)
        min_disp: 最小视差
        max_disp: 最大视差
    
    Returns:
        disparity: 视差图
        left_census: 左图Census码（用于验证）
        right_census: 右图Census码（用于验证）
    """
    h, w = left.shape
    disparity = np.zeros((h, w), dtype=np.uint8)
    
    # Census变换
    print(f"Computing {window_size}x{window_size} Census transform...")
    if window_size == 3:
        left_census = census_transform_3x3(left)
        right_census = census_transform_3x3(right)
        border = 1
    else:  # 5x5
        left_census = census_transform_5x5(left)
        right_census = census_transform_5x5(right)
        border = 2
    
    print(f"Census transform done. Left census example: {left_census[10, 10]:08b}")
    
    # 视差搜索
    print("Searching for disparities...")
    for i in range(border, h-border):
        if i % 20 == 0:
            print(f"  Processing row {i}/{h-border}")
        
        for j in range(max_disp, w-border):
            min_hamming = 255
            best_d = min_disp
            
            # 遍历视差范围
            for d in range(min_disp, max_disp+1):
                if j-d >= 0:
                    # 计算Hamming距离
                    hamming = hamming_distance(
                        left_census[i, j],
                        right_census[i, j-d]
                    )
                    
                    # 更新最小值
                    if hamming < min_hamming:
                        min_hamming = hamming
                        best_d = d
            
            # 归一化到0-255
            disparity[i, j] = int(best_d * (255.0 / max_disp))
    
    print("Disparity search done!")
    return disparity, left_census, right_census

def compare_with_ssd(left, right, window_size=7, min_disp=4, max_disp=10):
    """
    SSD算法实现（用于对比）
    """
    h, w = left.shape
    disparity = np.zeros((h, w), dtype=np.uint8)
    half_win = window_size // 2
    
    print(f"Computing SSD with {window_size}x{window_size} window...")
    
    for i in range(half_win, h-half_win):
        if i % 20 == 0:
            print(f"  Processing row {i}/{h-half_win}")
        
        for j in range(max_disp+half_win, w-half_win):
            min_ssd = float('inf')
            best_d = min_disp
            
            for d in range(min_disp, max_disp+1):
                if j-d >= half_win:
                    # 计算SSD
                    ssd = 0
                    for di in range(-half_win, half_win+1):
                        for dj in range(-half_win, half_win+1):
                            diff = int(left[i+di, j+dj]) - int(right[i+di, j-d+dj])
                            ssd += diff * diff
                    
                    if ssd < min_ssd:
                        min_ssd = ssd
                        best_d = d
            
            disparity[i, j] = int(best_d * (255.0 / max_disp))
    
    print("SSD done!")
    return disparity

def visualize_results(left, disparity_census, disparity_ssd=None, left_census=None):
    """可视化结果"""
    if disparity_ssd is not None:
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    else:
        fig, axes = plt.subplots(2, 2, figsize=(12, 10))
        axes = axes.flatten()
    
    # 左图
    axes[0].imshow(left, cmap='gray')
    axes[0].set_title('Left Image')
    axes[0].axis('off')
    
    # Census码可视化
    if left_census is not None:
        axes[1].imshow(left_census, cmap='viridis')
        axes[1].set_title('Left Census Code')
        axes[1].axis('off')
    
    # Census视差图
    axes[2].imshow(disparity_census, cmap='jet')
    axes[2].set_title('Census + Hamming Disparity')
    axes[2].axis('off')
    
    # Census伪彩色
    axes[3].imshow(disparity_census, cmap='turbo')
    axes[3].set_title('Census Disparity (Pseudo-color)')
    axes[3].axis('off')
    
    if disparity_ssd is not None:
        # SSD视差图
        axes[4].imshow(disparity_ssd, cmap='jet')
        axes[4].set_title('SSD Disparity')
        axes[4].axis('off')
        
        # 差异图
        diff = np.abs(disparity_census.astype(int) - disparity_ssd.astype(int))
        axes[5].imshow(diff, cmap='hot')
        axes[5].set_title('Difference (Census - SSD)')
        axes[5].axis('off')
    
    plt.tight_layout()
    return fig

def main():
    """主函数"""
    # 加载图像
    img_dir = Path('Img')
    left_img = cv2.imread(str(img_dir / 'Tsukuba_L.png'), cv2.IMREAD_GRAYSCALE)
    right_img = cv2.imread(str(img_dir / 'Tsukuba_R.png'), cv2.IMREAD_GRAYSCALE)
    
    if left_img is None or right_img is None:
        print("Error: Cannot load images. Check the path.")
        return
    
    print(f"Loaded images: {left_img.shape}")
    
    # Census立体匹配
    print("\n=== Census Transform + Hamming Distance ===")
    disparity_census_3x3, left_census_3x3, right_census_3x3 = census_stereo_matching(
        left_img, right_img, window_size=3, min_disp=4, max_disp=10
    )
    
    # 可选：5x5窗口
    # disparity_census_5x5, _, _ = census_stereo_matching(
    #     left_img, right_img, window_size=5, min_disp=4, max_disp=10
    # )
    
    # SSD匹配（对比）
    print("\n=== SSD (for comparison) ===")
    disparity_ssd = compare_with_ssd(
        left_img, right_img, window_size=7, min_disp=4, max_disp=10
    )
    
    # 保存结果
    output_dir = Path('Python_test_implementation')
    output_dir.mkdir(exist_ok=True)
    
    cv2.imwrite(str(output_dir / 'disparity_census_3x3.png'), disparity_census_3x3)
    cv2.imwrite(str(output_dir / 'disparity_ssd_7x7.png'), disparity_ssd)
    cv2.imwrite(str(output_dir / 'left_census_3x3.png'), left_census_3x3)
    
    # 保存伪彩色版本
    disparity_color = cv2.applyColorMap(disparity_census_3x3, cv2.COLORMAP_JET)
    cv2.imwrite(str(output_dir / 'disparity_census_3x3_color.jpg'), disparity_color)
    
    # 可视化
    fig = visualize_results(left_img, disparity_census_3x3, disparity_ssd, left_census_3x3)
    fig.savefig(output_dir / 'census_comparison.png', dpi=150)
    print(f"\nResults saved to {output_dir}/")
    
    # 统计信息
    print("\n=== Statistics ===")
    print(f"Census 3x3 - Mean disparity: {disparity_census_3x3[disparity_census_3x3>0].mean():.2f}")
    print(f"SSD 7x7 - Mean disparity: {disparity_ssd[disparity_ssd>0].mean():.2f}")
    print(f"Difference - Mean abs error: {np.abs(disparity_census_3x3.astype(int) - disparity_ssd.astype(int)).mean():.2f}")
    
    # 生成Verilog验证数据
    print("\n=== Generating Verilog test vectors ===")
    with open(output_dir / 'census_test_vectors.txt', 'w') as f:
        f.write("// Census Transform Test Vectors\n")
        f.write("// Format: row col left_pixel census_code_binary\n\n")
        for i in range(10, 20):  # 只输出几个测试点
            for j in range(10, 20):
                f.write(f"{i:3d} {j:3d} {left_img[i,j]:3d} {left_census_3x3[i,j]:08b}\n")
    
    print("Done! You can now compare with Verilog simulation results.")
    plt.show()

if __name__ == '__main__':
    main()

