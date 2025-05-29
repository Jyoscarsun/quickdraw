module conv1_w(
    output logic signed [7:0] weights[0:15][0:2][0:2]
);
    // Declare memory array
    logic signed [7:0] memory [0:143];

    // Load memory contents from a file during initialization
    initial begin
        $readmemh("parameters/conv1_w.mif", memory);
    end

    // Map the linear memory to the 3D weights structure
    initial begin
        for (int f = 0; f < 16; f++) begin
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    weights[f][i][j] = memory[(f * 9) + (i * 3) + j];
                end
            end
        end
    end
endmodule

module conv1_b(
    output logic signed [31:0] biases[0:15]
);
    logic signed [31:0] memory [0:15];

    inital begin
        $readmemh("parameters/conv1_b.mif", memory);
    end

    inital begin
        for(int i = 0; i < 16; i++)begin
            biases[i] = memory[i];
        end
    end
endmodule

module conv2_w(
    output logic signed [7:0] weights[0:31][0:15][0:2][0:2].
);
    //Hardware specific, Altera/intel FPGA has M10K memory blocks
    (* ramstyle = "M10K" *) logic signed [7:0] memory [0:4607];

    initial begin
        $readmemh("parameters/conv2_w.mif", memory);
    end

    genvar f, c, i, j;
    generate
        for(f = 0; f < 32; f++) begin: filter_loop
            for(c = 0; c < 16; c++) begin: channel_loop
                for(i = 0; i < 3; i++) begin: row_loop
                    for(j = 0; j < 3; j++) begin: col_loop
                        assign weights[f][c][i][j] = memory[(f*16*9) + (c*9) + (i*3) + j];
                    end
                end
            end
        end
    endgenerate
endmodule

module conv2_b(
    output logic signed [31:0] biases[0:31],
);  
    logic signed [31:0] memory [0:31];

    inital begin
        $readmemh("parameters/conv2_b.mif", memory);
    end

    inital begin
        for(int i = 0; i < 31; i++)begin
            biases[i] = memory[i];
        end
    end
endmodule

module fc1_w(
    output logic signed [7:0] weights[0:127][0:1567],
);
    //number of parallel memory banks (TUNE based on available resources)
    localparam NUM_BANKS = 16;
    localparam WEIGHTS_PER_BANK = 200704/NUM_BANKS;

    //declare memory banks with M10K directive (Altera/Intel FPGA specific)
    genvar bank;
    generate
        for(bank = 0; bank < NUM_BANKS, bank++)begin: memory_banks
            //each abnk stores some weights
            (* ramstyle = "M10K" *)
            logic signed[7:0] mem_bank[0:WEIGHTS_PER_BANK-1];

            //initialize each bank with its portion of weights
            initial begin
                //need to manuall split the file, again depend on NUM_BANKS parameter
                $readmemh($sformatf("parameters/fc1_w_bank%0d.mif", bank), mem_bank);
                end
            end
        end
    endgenerate

    //map from memory banks to output weight structure
    genvar neuron, input_idx;
    generate
        for(neuron = 0; neuron < 128; neuron++) begin: neuron_map
            for(input_idx = 0; input_idx < 1568; input_idx++) begin: input_map
                localparam int bank_idx = (neuron*1568 + input_idx) % NUM_BANKS;
                localparam int bank_addr = (neuron*1568 + input_idx) / NUM_BANKS;

                //connect weight to appropriate memory bank
                assign weights[neuron][input_idx] = memory_banks[bank_idx].mem_bank[bank_addr];
            end
        end
    endgenerate
endmodule

module fc1_b(
    output logic signed [31:0] biases[0:127]
);
    logic signed [31:0] memory [0:127];

    initial begin
        $readmemh("parameters/fc1_b.mif", memory);
    end

    initial begin
        for (int i = 0; i < 128; i++) begin
            biases[i] = memory[i];
        end
    end
endmodule

module fc2_w(
    output logic signed [7:0] weights[0:9][0:127]
);
    (* ramstyle = "M10K" *) logic signed [7:0] memory [0:1279];

    initial begin
        $readmemh("parameters/fc2_w.mif", memory);
    end
    
    genvar class_idx, input_idx;
    generate
        for (class_idx = 0; class_idx < 10; class_idx++) begin : classes
            for (input_idx = 0; input_idx < 128; input_idx++) begin : inputs
                // create direct paths from memory to output array
                assign weights[class_idx][input_idx] = memory[class_idx*128 + input_idx];
            end
        end
    endgenerate
endmodule

module fc2_b(
    output logic signed [31:0] biases[0:9]
);
    logic signed [31:0] memory [0:9];

    initial begin
        $readmemh("parameters/fc2_b.mif", memory);
    end

    initial begin
        for (int i = 0; i < 10; i++) begin
            biases[i] = memory[i];
        end
    end
endmodule