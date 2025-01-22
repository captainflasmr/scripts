#!/bin/bash

# Check if correct number of arguments is provided
if [ $# -ne 4 ]; then
    echo "Usage: $0 input_video trim_from_start trim_from_end output_video"
    echo "Example: $0 input.mp4 5 3 output.mp4"
    echo "This will trim 5 seconds from start and 3 seconds from end"
    exit 1
fi

# Assign arguments to variables
input_video="$1"
trim_start="$2"
trim_end="$3"
output_video="$4"

# Check if input file exists
if [ ! -f "$input_video" ]; then
    echo "Error: Input file '$input_video' does not exist"
    exit 1
fi

# Get video duration using ffprobe
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_video")
duration=${duration%.*}  # Remove decimal places

# Calculate end time by subtracting trim_end from total duration
end_time=$((duration - trim_end))

# Perform the trim operation
ffmpeg -i "$input_video" -ss "$trim_start" -t "$end_time" -c copy "$output_video"

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "Video trimmed successfully"
    echo "Original duration: $duration seconds"
    echo "New video: $output_video"
else
    echo "Error occurred while trimming video"
    exit 1
fi
