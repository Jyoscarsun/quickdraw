# quickdraw
CNN network architecture
The dimensions track correctly through your network:

Input: 28×28
Conv1: 26×26 (16 channels)
Pool1: 13×13 (16 channels)
Conv2: 13×13 (32 channels, with padding)
Pool2: 7×7 (32 channels)
FC1: flattened to 1568 inputs
FC2: 10 outputs
