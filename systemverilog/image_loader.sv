module image_loader(
    input logic clk,
    input logic reset,
    output logic signed [7:0] image [0:27][0:27], // 28x28 image
    output logic image_loaded
);
    // Memory to store image data
    logic [7:0] memory [0:783]; // 28*28 = 784 pixels
    
    // Fix path issue - use absolute or correct relative path
    initial begin
        $readmemh("../test_image.hex", memory); // Use ../ to go up one directory level
        
        // Debug output to verify file was found
        $display("Image loader: Loading test_image.hex");
    end
    
    // Flag to track initialization
    logic init_done = 0;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            image_loaded <= 0;
            init_done <= 0;
        end else if (!init_done) begin
            for (int i = 0; i < 28; i++) begin
                for (int j = 0; j < 28; j++) begin
                    image[i][j] <= memory[i*28 + j];
                end
            end
            image_loaded <= 1;
            init_done <= 1;
            
            // Debug: Display sample pixels to verify loading
            $display("Image loaded! Sample pixels: [0,0]=%h, [14,14]=%h, [27,27]=%h", 
                    memory[0], memory[14*28+14], memory[27*28+27]);
        end
    end
endmodule
