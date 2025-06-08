# Quickdraw Overview
This repository contains the code for hardware-accelerated inference of CNN network using the Quickdraw dataset. The Quickdraw dataset contains 28x28 pixel images of hand-drawn images grouped by different categories. Ten categories were selected and trained on with a CNNN neural network. The weights are then exported onto a DE1-SOC board to perform inference on test images. 

## Network Architecture
CNN network architecture
The dimensions track correctly through your network:

Input: 28×28
Conv1: 26×26 (16 channels)
Pool1: 13×13 (16 channels)
Conv2: 13×13 (32 channels, with padding)
Pool2: 7×7 (32 channels)
FC1: flattened to 1568 inputs
FC2: 10 outputs
