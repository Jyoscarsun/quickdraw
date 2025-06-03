module pool2(
    input logic clk,
    input logic reset,
    input logic start,
    output logic done,
    
    input logic signed [31:0] feature_maps[0:31][0:13][0:13],
    output logic signed [31:0] pooled_maps[0:31][0:6][0:6]
);
    typedef enum logic [1:0] {IDLE, POOLING, DONE, WAIT_START_LOW} state_t;
    state_t state, next_state;
    
    logic [4:0] f; 
    logic [2:0] i, j; 
    
    logic signed [31:0] max_val;
    
    // State machine and control logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            {done, f, i, j} <= '0;
        end else begin
            state <= next_state;
            
            if (next_state == DONE && state != DONE)
                done <= 1;  // Set when entering DONE state
            else if (next_state != DONE && state == DONE)
                done <= 0;  // Clear when leaving DONE state

            if (state == POOLING) begin
                max_val = feature_maps[f][i*2][j*2]; // Assume top left is the maximum value
                
                if (feature_maps[f][i*2][j*2+1] > max_val) // Top right
                    max_val = feature_maps[f][i*2][j*2+1];
                if (feature_maps[f][i*2+1][j*2] > max_val) // Bottom left
                    max_val = feature_maps[f][i*2+1][j*2];
                if (feature_maps[f][i*2+1][j*2+1] > max_val) // Bottom right
                    max_val = feature_maps[f][i*2+1][j*2+1];
                
                // Store result
                pooled_maps[f][i][j] <= max_val;
                
                if (j < 6) begin
                    j <= j + 1;
                end else begin
                    j <= 0;
                    if (i < 6) begin
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        if (f < 31) begin
                            f <= f + 1;
                        end
                    end
                end
            end
        end
    end
    
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: if (start) next_state = POOLING;
            POOLING: if (f == 31 && i == 6 && j == 6) next_state = DONE;
            DONE: next_state = WAIT_START_LOW;
            WAIT_START_LOW: if(!start) next_state = IDLE; //add new state transition
        endcase
    end

endmodule
