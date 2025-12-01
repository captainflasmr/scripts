#!/bin/bash

# Script to regenerate missing thumbnail images for folder galleries
# Each folder should have a corresponding .jpg file with the same name as the folder

# Function to check if a file is an image
is_image() {
    local file="$1"
    case "${file,,}" in
        *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.tiff|*.tif|*.webp)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to copy and rename image
copy_thumbnail() {
    local source_file="$1"
    local target_file="$2"
    
    # Use ImageMagick convert if available, otherwise use cp
    if command -v convert &> /dev/null; then
        convert "$source_file" "$target_file"
        echo "  → Converted '$source_file' to '$target_file'"
    else
        cp "$source_file" "$target_file"
        echo "  → Copied '$source_file' to '$target_file'"
    fi
}

echo "Scanning for missing thumbnail images..."
echo "========================================"

# Counter for statistics
missing_count=0
created_count=0

# Loop through all directories in current directory
for dir in */; do
    # Remove trailing slash from directory name
    dir_name="${dir%/}"
    
    # Skip if not a directory
    [ ! -d "$dir_name" ] && continue
    
    # Expected thumbnail filename
    thumbnail_file="${dir_name}.jpg"
    
    # Check if thumbnail already exists
    if [ -f "$thumbnail_file" ]; then
        echo "✓ $dir_name (thumbnail exists)"
        continue
    fi
    
    echo "✗ $dir_name (thumbnail missing)"
    ((missing_count++))
    
    # Find all image files in the directory
    image_files=()
    while IFS= read -r -d '' file; do
        if is_image "$file"; then
            image_files+=("$file")
        fi
    done < <(find "$dir_name" -maxdepth 1 -type f -print0)
    
    # Check if any images were found
    if [ ${#image_files[@]} -eq 0 ]; then
        echo "  ⚠ No image files found in '$dir_name'"
        continue
    fi
    
    # Select a random image from the array
    random_index=$((RANDOM % ${#image_files[@]}))
    selected_image="${image_files[$random_index]}"
    
    echo "  Found ${#image_files[@]} image(s) in '$dir_name'"
    echo "  Selected: '$(basename "$selected_image")'"
    
    # Copy the selected image as thumbnail
    if copy_thumbnail "$selected_image" "$thumbnail_file"; then
        ((created_count++))
    else
        echo "  ⚠ Failed to create thumbnail for '$dir_name'"
    fi
    
    echo
done

echo "========================================"
echo "Summary:"
echo "  Missing thumbnails found: $missing_count"
echo "  Thumbnails created: $created_count"

if [ $missing_count -eq 0 ]; then
    echo "  All thumbnails are present!"
elif [ $created_count -eq $missing_count ]; then
    echo "  All missing thumbnails have been created!"
else
    echo "  Some thumbnails could not be created. Check the warnings above."
fi
