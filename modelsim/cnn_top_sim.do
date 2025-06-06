vlib work

# Compile all sv files
vlog -sv ../systemverilog/parameter_loader.sv
vlog -sv ../systemverilog/image_loader.sv
vlog -sv ../systemverilog/conv1.sv
vlog -sv ../systemverilog/pool1.sv
vlog -sv ../systemverilog/conv2.sv
vlog -sv ../systemverilog/pool2.sv
vlog -sv ../systemverilog/fc1.sv
vlog -sv ../systemverilog/fc2.sv
vlog -sv ../systemverilog/cnn_top.sv

vsim -novopt work.cnn_top
source visualize_image.tcl

# Add basic control signals
add wave -position insertpoint -radix unsigned sim:/cnn_top/clk
add wave -position insertpoint -radix unsigned sim:/cnn_top/reset
add wave -position insertpoint -radix unsigned sim:/cnn_top/start
add wave -position insertpoint -radix unsigned sim:/cnn_top/done
add wave -position insertpoint -radix unsigned sim:/cnn_top/predicted_class

# layer control signals
add wave -divider "Layer Control"
add wave -position insertpoint sim:/cnn_top/conv1_start
add wave -position insertpoint sim:/cnn_top/conv1_done
add wave -position insertpoint sim:/cnn_top/pool1_start
add wave -position insertpoint sim:/cnn_top/pool1_done
add wave -position insertpoint sim:/cnn_top/conv2_start
add wave -position insertpoint sim:/cnn_top/conv2_done
add wave -position insertpoint sim:/cnn_top/pool2_start
add wave -position insertpoint sim:/cnn_top/pool2_done
add wave -position insertpoint sim:/cnn_top/fc1_start
add wave -position insertpoint sim:/cnn_top/fc1_done
add wave -position insertpoint sim:/cnn_top/fc2_start
add wave -position insertpoint sim:/cnn_top/fc2_done

# for conv1 signal debug
# Add these signals to help debug
add wave -position insertpoint sim:/cnn_top/conv1_layer/state
add wave -position insertpoint sim:/cnn_top/conv1_layer/next_state
add wave -position insertpoint sim:/cnn_top/conv1_layer/f
add wave -position insertpoint sim:/cnn_top/conv1_layer/i
add wave -position insertpoint sim:/cnn_top/conv1_layer/j

# add state machine state
add wave -position insertpoint sim:/cnn_top/state

# add sample values from each layer's output
add wave -divider "Layer Outputs (Sample Values)"
add wave -position insertpoint {sim:/cnn_top/input_image[14][14]}
add wave -position insertpoint {sim:/cnn_top/conv1_output[0][12][12]}
add wave -position insertpoint {sim:/cnn_top/pool1_output[0][6][6]}
add wave -position insertpoint {sim:/cnn_top/conv2_output[0][6][6]}
add wave -position insertpoint {sim:/cnn_top/pool2_output[0][3][3]}
add wave -position insertpoint {sim:/cnn_top/fc1_output[0]}
add wave -position insertpoint -radix decimal sim:/cnn_top/fc2_output

# create clock signal
force -deposit sim:/cnn_top/clk 0 0, 1 0.1ns -repeat 0.2ns

# intialize with reset
force -deposit sim:/cnn_top/reset 1 0
force -deposit sim:/cnn_top/start 0 0
run 40ns

# release reset and start processing
force -deposit sim:/cnn_top/reset 0 0
run 20ns
force -deposit sim:/cnn_top/start 1 0
run 20ns
force -deposit sim:/cnn_top/start 0 0

# run until done is asserted or timeout
set max_time 10000000
set increment 1000
set time 0

# Add checkpoint display statements at each state transition
when {sim:/cnn_top/state == "CONV1_EXEC"} {
    echo "Starting CONV1 execution"
}
when {sim:/cnn_top/conv1_done == 1} {
    echo "CONV1 completed - Sample output value: [examine -decimal {sim:/cnn_top/conv1_output[0][0][0]}]"
}
when {sim:/cnn_top/state == "POOL1_EXEC"} {
    echo "Starting POOL1 execution"
}
when {sim:/cnn_top/pool1_done == 1} {
    echo "POOL1 completed - Sample output value: [examine -decimal {sim:/cnn_top/pool1_output[0][0][0]}]"
}
when {sim:/cnn_top/state == "CONV2_EXEC"} {
    echo "Starting CONV2 execution"
}
when {sim:/cnn_top/conv2_done == 1} {
    echo "CONV2 completed - Sample output value: [examine -decimal {sim:/cnn_top/conv2_output[0][0][0]}]"
}
when {sim:/cnn_top/state == "POOL2_EXEC"} {
    echo "Starting POOL2 execution"
}
when {sim:/cnn_top/pool2_done == 1} {
    echo "POOL2 completed - Sample output value: [examine -decimal {sim:/cnn_top/pool2_output[0][0][0]}]"
}
when {sim:/cnn_top/state == "FC1_EXEC"} {
    echo "Starting FC1 execution"
}
when {sim:/cnn_top/fc1_done == 1} {
    echo "FC1 completed - Sample output value: [examine -decimal {sim:/cnn_top/fc1_output[0]}]"
}
when {sim:/cnn_top/state == "FC2_EXEC"} {
    echo "Starting FC2 execution"
}
when {sim:/cnn_top/fc2_done == 1} {
    echo "FC2 completed - Sample output values:"
    for {set i 0} {$i < 10} {incr i} {
        set value [examine -decimal -value sim:/cnn_top/fc2_output\[$i\]]
        echo "  Class $i: $value"
    }
}

while {$time < $max_time} {
    run $increment
    set time [expr $time + $increment]

    if {[examine -value sim:/cnn_top/done] == 1} {
        break
    }
}

# Display the final results
echo "-------------------------------------------"
echo "CNN Inference Results"
echo "-------------------------------------------"
echo "Execution completed: [examine -value sim:/cnn_top/done]"
echo "Predicted class: [examine -decimal -value sim:/cnn_top/predicted_class]"
echo "-------------------------------------------"
echo "Class probabilities (logits):"
for {set i 0} {$i < 10} {incr i} {
    set value [examine -decimal -value sim:/cnn_top/fc2_output\[$i\]]
    echo "  Class $i: $value"
}
echo "-------------------------------------------"
