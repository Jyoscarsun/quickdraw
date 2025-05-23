# image_loader_sim.do - ModelSim simulation script for image_loader

vlib work
vlog -sv ../systemverilog/image_loader.sv
vsim -novopt work.image_loader
add wave -position insertpoint sim:/image_loader/image

# Optional: Add more specific signals to view individual pixels
add wave -position insertpoint sim:/image_loader/image[0][0]
add wave -position insertpoint sim:/image_loader/image[0][1]
add wave -position insertpoint sim:/image_loader/image[14][14] 
add wave -position insertpoint sim:/image_loader/image[27][27]

# Run the simulation for enough time for initial blocks to execute
run 100ns

# Display some pixel values to verify loading
echo "Displaying sample pixel values:"
examine -decimal sim:/image_loader/image[0][0]
examine -decimal sim:/image_loader/image[10][10]
examine -decimal sim:/image_loader/image[20][20]
examine -decimal sim:/image_loader/image[27][27]