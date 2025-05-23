module image_loader(
    output logic signed [7:0] image [0:27][0:27]
);
    logic [7:0] memory [0:783];
    
    initial begin
        $readmemh("test_image.hex", memory);
        
        for (int i = 0; i < 28; i++) begin
            for (int j = 0; j < 28; j++) begin
                image[i][j] = $signed(memory[i*28 + j]);
            end
        end
    end
endmodule