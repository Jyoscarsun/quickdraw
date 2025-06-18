module fc1(
    input logic clk,
    input logic reset,
    input logic start,
    output logic done, 

    input logic signed [31:0] pool2_output [0:31][0:6][0:6],

    input logic signed [7:0] weights[0:127][0:1567],
    input logic signed [31:0] biases[0:127],

    output logic signed [31:0] fc_output[0:127] //128 output neurons
);
    typedef enum logic [3:0] {IDLE, INIT_NEURON, PROCESS_CHUNK, APPLY_RELU, NEXT_NEURON, DONE, WAIT_START_LOW} state_t;
    state_t state, next_state;

    logic [6:0] neuron_idx;           // Current output neuron (0-127) 
    logic [10:0] input_idx;           // Current input position (0-1567)
    logic signed [31:0] acc;          // Accumulator for dot product
    
    localparam CHUNK_SIZE = 8;

    // Function to convert from flattened index to 3D coordinates
    function logic signed [31:0] get_flattened_input(int ind);
        logic signed [31:0] result;
        int f, i, j;

        f = ind / 49; 
        i = (ind % 49) / 7;
        j = ind % 7;

        result = pool2_output[f][i][j];
        return result;
    endfunction

    // Main state machine logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            neuron_idx <= 0;
            input_idx <= 0;
            acc <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        neuron_idx <= 0;
                    end
                end
                
                INIT_NEURON: begin
                    acc <= biases[neuron_idx];
                    input_idx <= 0;
                end
                
                PROCESS_CHUNK: begin
                    // Process next input
                    acc <= acc + get_flattened_input(input_idx) * weights[neuron_idx][input_idx];
                    
                    // Increment with safety check
                    if (input_idx >= 1566) begin
                        input_idx <= 1567;  // Ensure we don't exceed max index
                    end else begin
                        input_idx <= input_idx + 1;
                    end
                end
                
                APPLY_RELU: begin
                    // Apply ReLU activation and store result
                    fc_output[neuron_idx] <= (acc < 0) ? 0 : acc;
                end
                
                NEXT_NEURON: begin
                    neuron_idx <= neuron_idx + 1;
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end
    
    // Next state logic with improved flow
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: 
                if (start) next_state = INIT_NEURON;
            
            INIT_NEURON: 
                next_state = PROCESS_CHUNK;
            
            PROCESS_CHUNK: 
                if (input_idx >= 1567) next_state = APPLY_RELU;
            
            APPLY_RELU: 
                next_state = NEXT_NEURON;
            
            NEXT_NEURON: 
                if (neuron_idx == 127) 
                    next_state = DONE;
                else 
                    next_state = INIT_NEURON;
            
            DONE: 
                next_state = WAIT_START_LOW;

            WAIT_START_LOW:
                if(!start) next_state = IDLE;
        endcase
    end
endmodule
