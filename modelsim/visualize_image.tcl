# CNN Image Visualizer for ModelSim
# Provides text-based visualization of CNN input images

# ASCII visualization of the input image
proc visualize_image_text {} {
    echo "\n======= INPUT IMAGE VISUALIZATION ======="
    
    # Use ASCII characters for intensity visualization
    for {set i 0} {$i < 28} {incr i} {
        set row ""
        for {set j 0} {$j < 28} {incr j} {
            set pixel [examine -decimal -value sim:/cnn_top/input_image\[$i\]\[$j\]]
            
            # Map pixel value (0-255) to ASCII character
            if {$pixel == "x"} {
                append row "?"
            } elseif {$pixel < 32} {
                append row " "
            } elseif {$pixel < 64} {
                append row "."
            } elseif {$pixel < 96} {
                append row ":"
            } elseif {$pixel < 128} {
                append row "o"
            } elseif {$pixel < 160} {
                append row "O"
            } elseif {$pixel < 192} {
                append row "#"
            } else {
                append row "@"
            }
        }
        echo $row
    }
    echo "========================================="
}

# Export image to CSV for external visualization
proc export_image_csv {} {
    # Create CSV file for the image
    set file [open "input_image.csv" w]
    
    # Export all 28x28 pixels
    for {set i 0} {$i < 28} {incr i} {
        set row ""
        for {set j 0} {$j < 28} {incr j} {
            set pixel [examine -decimal -value sim:/cnn_top/input_image\[$i\]\[$j\]]
            append row "$pixel,"
        }
        puts $file $row
    }
    close $file
    echo "Image exported to input_image.csv"
}

# Register visualization triggers
echo "Registering image visualization triggers..."
when {sim:/cnn_top/state == "CONV1_EXEC"} {
    echo "Input image loaded, showing visualization:"
    visualize_image_text
    export_image_csv
}

echo "Image visualizer loaded successfully."