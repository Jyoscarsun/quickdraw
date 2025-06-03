module filter_unit2_pipeline(
    input logic clk,
    input logic reset,
    input logic valid_in,
    output logic valid_out,

    input logic signed [31:0] window[0:15][0:2][0:2],
    input logic signed [7:0] w[0:15][0:2][0:2],
    input logic signed [31:0] b,
    output logic signed [31:0] result
);  
    logic signed [31:0] partial_sums[0:16]; //16 channels + bias
    logic [16:0] valid_pipe; //valid signal through pipeline

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            partial_sums[0] <= 0;
            valid_pipe[0] <= 0;
        end else begin
            partial_sums[0] <= b;
            valid_pipe[0] <= valid_in;
        end
    end

    genvar i;
    generate
        for(i=0; i<16; i++) begin: channel_units
            //3x3 convolution results for this channel
            logic signed [31:0] channel_result;
            always_comb begin
                channel_result = window[i][0][0] * w[i][0][0] + 
                                window[i][0][1] * w[i][0][1] + 
                                window[i][0][2] * w[i][0][2] + 
                                window[i][1][0] * w[i][1][0] + 
                                window[i][1][1] * w[i][1][1] + 
                                window[i][1][2] * w[i][1][2] + 
                                window[i][2][0] * w[i][2][0] + 
                                window[i][2][1] * w[i][2][1] + 
                                window[i][2][2] * w[i][2][2];
            end

            always_ff @(posedge clk or posedge reset) begin
                if(reset) begin
                    partial_sums[i+1] <= 0;
                    valid_pipe[i+1] <= 0;
                end else begin
                    partial_sums[i+1] <= partial_sums[i] + channel_result;
                    valid_pipe[i+1] <= valid_pipe[i];
                end
            end
        end
    endgenerate

    // ReLU
    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            result <= (partial_sums[16] < 0) ? 0 : partial_sums[16];
            valid_out <= valid_pipe[16];
        end
    end
endmodule 

module conv2(
    input logic clk,
    input logic reset,

    input logic signed [31:0] pool1_maps[0:15][0:13][0:13],
    input logic start,
    output logic done,

    input logic signed [7:0] weights[0:31][0:15][0:2][0:2],
    input logic signed [31:0] biases[0:31],

    output logic signed [31:0] output_maps[0:31][0:13][0:13] //32 output feature maps of 14x14 with padding=1
);
    // state machine
    typedef enum logic [2:0] {IDLE, SETUP, COMPUTE, WAIT_PIPE, NEXT_PIXEL, DONE, WAIT_START_LOW} state_t;
    state_t state, next_state;

    // Counters to track progress
    logic [4:0] f; //filter index 0-31
    logic [3:0] i, j; //output coord 0-13

    // current window with implicit padding
    logic signed [31:0] cur_window[0:15][0:2][0:2];

    logic pipe_valid_in, pipe_valid_out;
    logic signed [31:0] pipe_result;

    logic [4:0] wait_count;

    // implicit padding
    always_comb begin
        // Declare variables at the beginning
        int im, jn;
        
        for(int c = 0; c < 16; c++) begin
            for(int m = 0; m < 3; m++) begin
                for(int n = 0; n < 3; n++) begin
                    // Assign values separately from declaration
                    im = i+m-1;
                    jn = j+n-1;

                    if(im < 0 || im >= 14 || jn < 0 || jn >=14) 
                        cur_window[c][m][n]=0;
                    else
                        cur_window[c][m][n]=pool1_maps[c][im][jn];
                end
            end
        end
    end

    
    filter_unit2_pipeline fp(
        .clk(clk),
        .reset(reset),
        .valid_in(pipe_valid_in),
        .valid_out(pipe_valid_out),
        .window(cur_window),
        .w(weights[f]),
        .b(biases[f]),
        .result(pipe_result)
    );

    //state machine logic
    always_ff @(posedge clk or posedge reset)begin
        if(reset) begin
            state <= IDLE;
            {done, f, i, j, pipe_valid_in, wait_count} <= '0;
        end else begin
            state <= next_state;
            case(state)
                IDLE: begin
                    if(start) begin
                        {f, i, j, done} <= '0;
                    end
                end

                SETUP: begin
                    pipe_valid_in <= 1; // start pipeline
                end

                COMPUTE: begin
                    pipe_valid_in <= 0; //reset pipe_valid_in
                    wait_count <= 0;
                end

                WAIT_PIPE: begin
                    wait_count <= wait_count + 1;
                    // store result when it's valid
                    if(pipe_valid_out) begin
                        output_maps[f][i][j] = pipe_result;
                    end 
                end

                NEXT_PIXEL: begin
                    //update position
                    if(j < 13) begin
                        j<=j+1;
                    end else begin
                        j <= 0;
                        if(i<13) begin
                            i <= i+1;
                        end else begin
                            i <= 0;
                            if (f < 31)begin 
                                f<=f+1;
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    //next state logic
    always_comb begin
        next_state = state;
        
        case(state)
            IDLE: 
                if(start) next_state = SETUP;
            
            SETUP: 
                next_state = COMPUTE;

            COMPUTE:
                next_state = WAIT_PIPE;

            WAIT_PIPE:
                //basically a timeout because normally filter_pipeline takes 17 cycles to finish
                if(pipe_valid_out || wait_count >= 20) next_state = NEXT_PIXEL;

            NEXT_PIXEL:
                if(f==31 && i==13 && j==13)
                    next_state = DONE;
                else 
                    next_state = SETUP;
            
            DONE:
                next_state = WAIT_START_LOW;

            WAIT_START_LOW: begin
                if(!start) next_state = IDLE; // only go to IDLE when start is low
            end
        endcase
    end
endmodule
