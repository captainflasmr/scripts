#! /bin/bash

echo

# Loop through all items in the current directory
for dir in */; do
    # Ensure it is a directory
    if [ -d "$dir" ]; then
        # Calculate total size with `du`
        size=$(du -sh "$dir" | cut -f1)

        # Count the number of files recursively
        file_count=$(find "$dir" -type f | wc -l)

        # Output the result
        echo "$dir $size $file_count"
    fi
done

echo
