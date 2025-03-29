#!/bin/bash

# Declare an associative array to store checksums
declare -A file_checksums

# Function to calculate the checksum of a file
calculate_checksum() {
    local file="$1"
    # Use md5sum for checksum calculation; you can also use sha256sum or other checksum tools
    md5sum "$file" | awk '{ print $1 }'
}

# Iterate over each file in the current directory
for file in *; do
    # Check if it is a regular file
    if [[ -f "$file" ]]; then
        # Calculate the file's checksum
        checksum=$(calculate_checksum "$file")

        # Check if this checksum is already in the array
        if [[ -n "${file_checksums[$checksum]}" ]]; then
            echo "Duplicate content found: '$file' and '${file_checksums[$checksum]}'"
        else
            # Store the file path in the array with its checksum as the key
            file_checksums[$checksum]="$file"
        fi
    fi
done
