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