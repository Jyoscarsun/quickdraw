module pool1(
    input logic clk,
    input logic reset,
    input logic start,
    output logic done,

    input logic signed [31:0] feature_maps[0:15][0:25][0:25],
    output logic signed [31:0] pooled_maps[0:15][0:13][0:13]
);
    typedef enum logic [1:0] {IDLE, POOLING, DONE, WAIT_START_LOW} state_t;
    state_t state, next_state;

    // Counters for feature maps
    logic [3:0] f; // Feature map index
    logic [3:0] i, j; // Output coordinates

    // Max value within maps
    logic signed [31:0] max_val;

    always_ff @(posedge clk or posedge reset) begin  
        if(reset) begin
            state <= IDLE;
            done <= 0;
            {f, i, j} <= '0;
        end
        else begin
            state <= next_state;

            // Set done signal in sequential block only
            if (next_state == DONE && state != DONE)
                done <= 1;
            else if (next_state != DONE && state == DONE)
                done <= 0;

            if(state == POOLING) begin
                // Find the maximum of the 2x2 window
                max_val = feature_maps[f][i*2][j*2]; // Assume top left is the maximum value
                
                if(feature_maps[f][i*2][j*2+1] > max_val) // Top right
                    max_val = feature_maps[f][i*2][j*2+1];
                if(feature_maps[f][i*2+1][j*2] > max_val) // Bottom left
                    max_val = feature_maps[f][i*2+1][j*2];
                if(feature_maps[f][i*2+1][j*2+1] > max_val) // Bottom right
                    max_val = feature_maps[f][i*2+1][j*2+1];

                // Store result
                pooled_maps[f][i][j] <= max_val;

                // Update indices
                if(j < 13) begin
                    j <= j+1;
                end else begin
                    j <= 0;
                    if(i < 13) begin
                        i <= i+1;
                    end else begin
                        i <= 0;
                        if(f < 15) begin
                            f <= f+1;
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
            IDLE: if(start) next_state = POOLING;
            POOLING: if(f==15 && i == 13 && j == 13) next_state = DONE;
            DONE: next_state = WAIT_START_LOW;
            WAIT_START_LOW: if(!start) next_state = IDLE; 
        endcase
    end

endmodule
