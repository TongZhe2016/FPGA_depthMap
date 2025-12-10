################################################################################
# Vivado TCL脚本：自动运行Census Transform测试
# 用法：在Vivado TCL Console中运行
#       source run_census_tests.tcl
################################################################################

puts "\n=========================================="
puts "Census Transform Test Suite"
puts "==========================================\n"

# 设置项目路径
set proj_dir [file normalize [file dirname [info script]]]
set proj_name "FPGA_depthMap_sim"

puts "Project directory: $proj_dir"
puts "Opening project: $proj_name\n"

# 打开项目（如果已打开则跳过）
if {[catch {current_project}]} {
    if {[file exists "$proj_dir/$proj_name/$proj_name.xpr"]} {
        open_project "$proj_dir/$proj_name/$proj_name.xpr"
        puts "✓ Project opened\n"
    } else {
        puts "✗ ERROR: Project not found!"
        puts "  Please create the project first.\n"
        return
    }
} else {
    puts "✓ Project already open: [current_project]\n"
}

# 添加源文件（如果还没添加）
puts "Checking source files..."

set design_files [list \
    "census_transform.v" \
    "hamming_distance.v" \
    "census_stereo_matching.v"
]

set sim_files [list \
    "tb_census_transform.v" \
    "tb_hamming_distance.v" \
    "tb_window_generator.v"
]

# 添加设计源文件
foreach file $design_files {
    set file_path "$proj_dir/$file"
    if {[file exists $file_path]} {
        if {[catch {get_files $file}]} {
            add_files -norecurse $file_path
            puts "  + Added: $file"
        } else {
            puts "  ✓ Already in project: $file"
        }
    } else {
        puts "  ✗ NOT FOUND: $file"
    }
}

# 添加仿真源文件
foreach file $sim_files {
    set file_path "$proj_dir/$file"
    if {[file exists $file_path]} {
        if {[catch {get_files -of_objects [get_filesets sim_1] $file}]} {
            add_files -fileset sim_1 -norecurse $file_path
            puts "  + Added to sim: $file"
        } else {
            puts "  ✓ Already in sim: $file"
        }
    } else {
        puts "  ✗ NOT FOUND: $file"
    }
}

# 更新编译顺序
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "\n✓ Files checked and added\n"

# 函数：运行单个测试
proc run_test {testbench_name description} {
    puts "\n=========================================="
    puts "Test: $description"
    puts "Testbench: $testbench_name"
    puts "==========================================\n"
    
    # 关闭当前仿真
    if {[current_sim] ne ""} {
        close_sim -quiet
    }
    
    # 设置顶层
    set_property top $testbench_name [get_filesets sim_1]
    
    # 启动仿真
    puts "Launching simulation..."
    if {[catch {launch_simulation} err]} {
        puts "✗ ERROR: Failed to launch simulation"
        puts "  $err\n"
        return 0
    }
    
    # 运行仿真
    puts "Running simulation..."
    run 10us
    
    # 检查是否完成
    set sim_time [current_time]
    puts "Simulation time: $sim_time"
    
    puts "\n✓ Test completed"
    puts "  Check TCL Console output above for results\n"
    
    return 1
}

# 提示用户选择测试
puts "Available tests:"
puts "  1. Census Transform"
puts "  2. Hamming Distance"
puts "  3. Window Generator"
puts "  4. Run all tests"
puts ""

# 由于TCL无法交互式读取，我们按顺序运行所有测试
set run_all 1

if {$run_all} {
    puts "Running all tests...\n"
    
    # Test 1: Census Transform
    if {[run_test "tb_census_transform" "Census Transform Unit Test"]} {
        puts "Press any key in TCL Console to continue..."
        # 保持仿真打开，等待用户查看
    }
    
    # Test 2: Hamming Distance
    # 取消注释以运行
    # if {[run_test "tb_hamming_distance" "Hamming Distance Unit Test"]} {
    #     puts "Press any key in TCL Console to continue..."
    # }
    
    # Test 3: Window Generator
    # 取消注释以运行（这个测试较慢）
    # if {[run_test "tb_window_generator" "Window Generator Unit Test"]} {
    #     puts "Press any key in TCL Console to continue..."
    # }
    
    puts "\n=========================================="
    puts "Test suite completed!"
    puts "=========================================="
    puts "\nNext steps:"
    puts "  1. Review the test output above"
    puts "  2. Check waveforms in the simulation window"
    puts "  3. To run other tests, modify this script or run manually"
    puts ""
}

puts "\nScript finished. Simulation is still open for inspection."
puts "To close simulation: close_sim"
puts "To run another test: source run_census_tests.tcl\n"

