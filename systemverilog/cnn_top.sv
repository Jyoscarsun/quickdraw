module cnn_top(
    input logic clk,
    input logic reset,
    input logic start,
    output logic done,
    output logic [3:0] predicted_class
);
    //Image input from file
    logic signed [7:0] input_image [0:27][0:27];

    //intermediate layer output
    logic signed [31:0] conv1_output[0:15][0:25][0:25];
    logic signed [31:0] pool1_output[0:15][0:13][0:13];
    logic signed [31:0] conv2_output[0:31][0:13][0:13];
    logic signed [31:0] pool2_output[0:31][0:6][0:6];
    logic signed [31:0] fc1_output[0:127];
    logic signed [31:0] fc2_output[0:9];

    //layer control signals
    logic conv1_done, pool1_done, conv2_done, pool2_done, fc1_done, fc2_done;
    logic conv1_start, pool1_start, conv2_start, pool2_start, fc1_start, fc2_start;

    //weights and biases from parameter loader
    logic signed [7:0] conv1_weights[0:15][0:2][0:2];
    logic signed [31:0] conv1_biases[0:15];
    logic signed [7:0] conv2_weights[0:31][0:15][0:2][0:2];
    logic signed [31:0] conv2_biases[0:31];
    logic signed [7:0] fc1_weights[0:127][0:1567];
    logic signed [31:0] fc1_biases[0:127];
    logic signed [7:0] fc2_weights[0:9][0:127];
    logic signed [31:0] fc2_biases[0:9]; 

    logic image_loaded;
    image_loader img_load(
        .image(input_image),
        .clk(clk),
        .reset(reset),
        .image_loaded(image_loaded)
    );

    //sv finds module by name, as long as in modelsim have file in command
    //like vlog -sv cnn_top.sv parameter_loader.sv conv1.sv pool1.sv conv2.sv pool2.sv fc1.sv fc2.sv

    conv1_w w1_loader(.weights(conv1_weights));
    conv1_b b1_loader(.biases(conv1_biases));
    conv2_w w2_loader(.weights(conv2_weights));
    conv2_b b2_loader(.biases(conv2_biases));
    fc1_w w3_loader(.weights(fc1_weights));
    fc1_b b3_loader(.biases(fc1_biases));
    fc2_w w4_loader(.weights(fc2_weights));
    fc2_b b4_loader(.biases(fc2_biases));

    // Layer implementations
    conv1 conv1_layer(
        .clk(clk),
        .reset(reset),
        .input_image(input_image),
        .t(conv1_start),
        .d(conv1_done),
        .weights(conv1_weights),
        .biases(conv1_biases),
        .output_map(conv1_output)
    );
    
    pool1 pool1_layer(
        .clk(clk),
        .reset(reset),
        .start(pool1_start),
        .done(pool1_done),
        .feature_maps(conv1_output),
        .pooled_maps(pool1_output)
    );
    
    conv2 conv2_layer(
        .clk(clk),
        .reset(reset),
        .pool1_maps(pool1_output),
        .start(conv2_start),
        .done(conv2_done),
        .weights(conv2_weights),
        .biases(conv2_biases),
        .output_maps(conv2_output)
    );
    
    pool2 pool2_layer(
        .clk(clk),
        .reset(reset),
        .start(pool2_start),
        .done(pool2_done),
        .feature_maps(conv2_output),
        .pooled_maps(pool2_output)
    );

    fc1 fc1_layer(
        .clk(clk),
        .reset(reset),
        .start(fc1_start),
        .done(fc1_done),
        .pool2_output(pool2_output),
        .weights(fc1_weights),
        .biases(fc1_biases),
        .fc_output(fc1_output)
    );
    
    fc2 fc2_layer(
        .clk(clk),
        .reset(reset),
        .start(fc2_start),
        .done(fc2_done),
        .fc1_output(fc1_output),
        .weights(fc2_weights),
        .biases(fc2_biases),
        .fc_output(fc2_output)
    );

    typedef enum logic [3:0] {IDLE, CONV1_EXEC, POOL1_EXEC, CONV2_EXEC, 
                             POOL2_EXEC, FC1_EXEC, FC2_EXEC, FIND_CLASS, FINISHED} state_t;
    state_t state, next_state;
    
    // Control state machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            predicted_class <= 4'd0;
        end else begin
            state <= next_state;
            
            // Find class with highest score when FC2 is complete
            if (state == FIND_CLASS) begin
                logic signed [31:0] max_val;
                logic [3:0] max_idx;
                
                // Initialize with first class
                max_val = fc2_output[0];
                max_idx = 0;
                
                // Find the class with the highest score
                for (int i = 1; i < 10; i++) begin
                    if (fc2_output[i] > max_val) begin
                        max_val = fc2_output[i];
                        max_idx = i[3:0];
                    end
                end

                predicted_class <= max_idx;
                done <= 1;
            end
        end
    end

    always_comb begin
        // Default all start signals to 0
        conv1_start = 0;
        pool1_start = 0;
        conv2_start = 0;
        pool2_start = 0;
        fc1_start = 0;
        fc2_start = 0;
        
        case (state)
            CONV1_EXEC: conv1_start = 1;
            POOL1_EXEC: pool1_start = 1;
            CONV2_EXEC: conv2_start = 1;
            POOL2_EXEC: pool2_start = 1;
            FC1_EXEC:   fc1_start = 1;
            FC2_EXEC:   fc2_start = 1;
            default:    ; // No layer active
        endcase
    end

    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: 
                if (start && image_loaded) next_state = CONV1_EXEC;
                
            CONV1_EXEC: 
                if (conv1_done) next_state = POOL1_EXEC;
                
            POOL1_EXEC: 
                if (pool1_done) next_state = CONV2_EXEC;
                
            CONV2_EXEC: 
                if (conv2_done) next_state = POOL2_EXEC;
                
            POOL2_EXEC: 
                if (pool2_done) next_state = FC1_EXEC;
                
            FC1_EXEC: 
                if (fc1_done) next_state = FC2_EXEC;
                
            FC2_EXEC: 
                if (fc2_done) next_state = FIND_CLASS;
            
            FIND_CLASS: 
                next_state = FINISHED;

            FINISHED: 
                if (!start) next_state = IDLE;
        endcase
    end
endmodule
