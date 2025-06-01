module fc2(
    input logic clk,
    input logic reset,
    input logic start,
    output logic done,

    input logic signed[31:0] fc1_output[0:127], //input is output of fc1
    input logic signed[7:0] weights[0:9][0:127], //10x128 weights
    input logic signed[31:0] biases[0:9], //10 biases

    output logic signed[31:0] fc_output[0:9] //10 neurons
);
    typedef enum logic [1:0] {IDLE, COMPUTING, DONE} state_t;
    state_t state, next_state;

    logic [3:0] ind; //index of the current neuron being processed
    logic signed [31:0] acc; //accumulate dot product output

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            state <= IDLE;
            done <= 0;
            ind <= 0;
            acc <= 0;
        end else begin
            state <= next_state;

            case(state)
                IDLE: begin
                    if(start) begin
                        done <= 0;
                        ind <=0;
                    end
                end

                COMPUTING: begin
                    acc = biases[ind]; //initiate acc with bias value
                    
                    //process all 128 inputs in one cycle
                    for(int i=0; i < 128; i++)begin
                        acc += fc1_output[i] * weights[ind][i];
                    end

                    fc_output[ind] <= acc;
                    ind <= ind+1;
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;

        case(state)
            IDLE: 
                if(start) next_state = COMPUTING;

            COMPUTING:
                if(ind == 9) next_state = DONE;

            DONE:
                next_state = IDLE; 
        endcase
    end
endmodule
