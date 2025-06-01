module filter_unit(
    input logic signed [7:0] window[0:2][0:2],
    input logic signed [7:0] w[0:2][0:2],
    input logic signed [31:0] b,
    output logic signed [31:0] result
);
    logic signed [31:0] sum;
    always_comb begin 
        sum = b;
        for (int m=0; m < 3; m++) begin
            for (int n=0; n < 3; n++) begin
                sum += window[m][n] * w[m][n];
            end
        end 
        result = (sum < 0) ? 0 : sum; // ReLU
    end
endmodule

module conv1(
    input logic clk,
    input logic reset,

    input logic signed [7:0] input_image [0:27][0:27], //28x28 input
    input logic t, // trigger to start convolution
    output logic d, // signal when done

    input logic signed [7:0] weights[0:15][0:2][0:2], //16 filters, 3x3
    input logic signed [31:0] biases [0:15],

    output logic signed[31:0] output_map[0:15][0:25][0:25] //16 outputs, 26x26
);
    // Define state machine for control
    typedef enum logic [1:0] {IDLE, COMPUTING, DONE} state_t;
    state_t state, next_state;
    
    // Registers for tracking progress
    logic [3:0] f;  // Filter index
    logic [4:0] i, j;  // Output map indices
    
    // Window extraction logic
    logic signed [7:0] current_window[0:2][0:2];
    
    // Single filter unit instantiation (reused for each calculation)
    logic signed [31:0] filter_result;
    
    // Extract window from input image
    always_comb begin
        for (int m = 0; m < 3; m++) begin
            for (int n = 0; n < 3; n++) begin
                current_window[m][n] = input_image[i+m][j+n];
            end
        end
    end
    
    // Instantiate a single filter unit
    filter_unit fu(
        .window(current_window),
        .w(weights[f]),
        .b(biases[f]),
        .result(filter_result)
    );
    
    // State machine and control logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            d <= 0;
            f <= 0;
            i <= 0;
            j <= 0;
        end else begin
            state <= next_state;

            if (next_state == DONE && state != DONE) begin
                d <= 1;  
            end else if (next_state != DONE && state == DONE) begin
                d <= 0;  
            end
            
            if (state == COMPUTING) begin
                // Store the result
                output_map[f][i][j] <= filter_result;
                
                // Update indices
                if (j < 25) begin
                    j <= j + 1;
                end else begin
                    j <= 0;
                    if (i < 25) begin
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        if (f < 15) begin
                            f <= f + 1;
                        end
                    end
                end
            end
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case(state)
            IDLE: if (t) next_state = COMPUTING;
            COMPUTING: begin
                if (f == 15 && i == 25 && j == 25) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
endmodule
