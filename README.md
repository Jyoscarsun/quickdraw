# Quickdraw Overview
This repository contains the code for hardware-accelerated inference of CNN network using the Quickdraw dataset. The Quickdraw dataset contains 28x28 pixel images of hand-drawn images grouped by different categories. Ten categories were selected and trained on with a CNNN neural network. The weights are then exported onto a DE1-SOC board to perform inference on test images. 

## Network Architecture
One of the main consideration for the architecture design is the feasibility for hardware to load weights. To achieve a network that is both compact and accurate, I implemented two convolutional layers (with pooling following) and two fully connected layers. The dimensions of all layers can be found below. 
* **Input**: 28×28 (784 features)
* **Conv1**: 26×26 (16 channels)
* **Pool1**: 13×13 (16 channels)
* **Conv2**: 13×13 (32 channels, with padding)
* **Pool2**: 7×7 (32 channels)
* **FC1**: flattened to 1568 inputs
* **FC2**: 10 outputs

## Hardware Implementation
1. Parallelized Convolution Operations
  The convolution layers implement parallel multiply-accumulate (MAC) operations:
  ```
  // Parallel channel computation in conv2
  for(i=0; i<16; i++) begin: channel_units
      always_comb begin
          channel_result = window[i][0][0] * w[i][0][0] + 
                          window[i][0][1] * w[i][0][1] + 
                          // ... other parallel multiplications
      end
  end
  ```
2. Advanced Pipelining
   The `filter_unit2_pipeline` module implements a deep pipeline architecture:
   * **16-Stage Pipeline**: Each input channel has its own pipeline stage
   * **Valid Signal Propagation**: Validity flags propagate through the pipeline
   * **Overlapped Processing**: New inputs can be processed before previous outputs complete
3. Implicit Padding
   Memory-efficient padding is implemented without additional storage:
   ```
   // Efficient implicit padding in conv2
  always_comb begin
      for(int c = 0; c < 16; c++) begin
          for(int m = 0; m < 3; m++) begin
              for(int n = 0; n < 3; n++) begin
                  if(im < 0 || im >= 14 || jn < 0 || jn >=14) 
                      cur_window[c][m][n]=0;  // Zero padding
                  else
                      cur_window[c][m][n]=pool1_maps[c][im][jn];
              end
          end
      end
  end
   ```
4. Hardware-Optimized Activation Functions: ReLU activation implemented directly in hardware
  ```
  // Hardware ReLU implementation
  result <= (partial_sums[16] < 0) ? 0 : partial_sums[16];
  ```
5. Efficient Parameter Loading: weights and biases are efficiently loaded
  * Parameter Loaders: Dedicated modules for weight/bias initialization
  * Memory Mapping: Direct mapping from hex files to hardware structures

## Performance Optimizations
Multi-Channel Processing: Processes multiple input channels simultaneously
Pipelined Execution: Overlaps computation across multiple pixels/filters
State Machine Pipeline: Efficiently sequences layer operations
Timeout Management: Ensures forward progress even with validation issues
