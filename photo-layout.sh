#!/bin/bash

# Flexible Photo Print Layout Script
# Usage: ./flexible-photo-layout.sh [options] image1.jpg:WxH image2.jpg:WxH ...
# 
# Examples:
#   ./flexible-photo-layout.sh photo1.jpg:4x6 photo2.jpg:4x6 photo3.jpg:3.375x2.125
#   ./flexible-photo-layout.sh --paper A4 --dpi 240 vacation.jpg:5x7 portrait.jpg:4x6 card.jpg:wallet
#   ./flexible-photo-layout.sh --margin 0.25 --spacing 0.3 img1.jpg:4x6 img2.jpg:square img3.jpg:2x3

# Default values
PAPER_SIZE="A3"
DPI=300
MARGIN=0.5        # inches
SPACING=0.25      # inches between images
OUTPUT_PREFIX="layout"

# Predefined size shortcuts
declare -A SIZE_PRESETS
SIZE_PRESETS["a5"]="5.8x8.3"
SIZE_PRESETS["4x6"]="4x6"
SIZE_PRESETS["5x7"]="5x7" 
SIZE_PRESETS["8x10"]="8x10"
SIZE_PRESETS["wallet"]="2.5x3.5"
SIZE_PRESETS["card"]="3.375x2.125"
SIZE_PRESETS["creditcard"]="3.375x2.125"
SIZE_PRESETS["square"]="4x4"
SIZE_PRESETS["passport"]="2x2"

# Paper size definitions (width x height in inches)
declare -A PAPER_SIZES
PAPER_SIZES["A3"]="11.7x16.5"
PAPER_SIZES["A4"]="8.3x11.7" 
PAPER_SIZES["Letter"]="8.5x11"
PAPER_SIZES["Legal"]="8.5x14"
PAPER_SIZES["Tabloid"]="11x17"

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] image1.jpg:size image2.jpg:size ..."
    echo ""
    echo "Options:"
    echo "  --paper SIZE     Paper size (A3, A4, Letter, Legal, Tabloid) [default: A3]"
    echo "  --dpi DPI        Print resolution [default: 300]"
    echo "  --margin INCH    Margin around edges [default: 0.5]"
    echo "  --spacing INCH   Space between images [default: 0.25]"
    echo "  --output NAME    Output filename prefix [default: layout]"
    echo "  --landscape      Force landscape orientation"
    echo "  --portrait       Force portrait orientation"
    echo "  --help           Show this help"
    echo ""
    echo "Size formats:"
    echo "  WIDTHxHEIGHT     Custom dimensions in inches (e.g., 4x6, 3.5x5)"
    echo "  PRESET           Use preset: 4x6, 5x7, 8x10, wallet, card, square, passport"
    echo ""
    echo "Examples:"
    echo "  $0 photo1.jpg:4x6 photo2.jpg:4x6 photo3.jpg:card"
    echo "  $0 --paper A4 --dpi 240 vacation.jpg:5x7 portrait.jpg:wallet"
    echo "  $0 --margin 0.25 --spacing 0.3 img1.jpg:4x6 img2.jpg:square"
}

# Parse command line arguments
IMAGES=()
FORCE_ORIENTATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --paper)
            PAPER_SIZE="$2"
            shift 2
            ;;
        --dpi)
            DPI="$2"
            shift 2
            ;;
        --margin)
            MARGIN="$2"
            shift 2
            ;;
        --spacing)
            SPACING="$2"
            shift 2
            ;;
        --output)
            OUTPUT_PREFIX="$2"
            shift 2
            ;;
        --landscape)
            FORCE_ORIENTATION="landscape"
            shift
            ;;
        --portrait)
            FORCE_ORIENTATION="portrait"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        --*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *:*)
            IMAGES+=("$1")
            shift
            ;;
        *)
            echo "Error: Arguments must be in format image.jpg:size"
            show_usage
            exit 1
            ;;
    esac
done

# Check if we have images
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Error: No images specified!"
    show_usage
    exit 1
fi

# Validate paper size
PAPER_DIMS="${PAPER_SIZES[$PAPER_SIZE]}"
if [ -z "$PAPER_DIMS" ]; then
    echo "Error: Unknown paper size '$PAPER_SIZE'"
    echo "Available sizes: ${!PAPER_SIZES[@]}"
    exit 1
fi

# Function to calculate aspect ratio
calc_aspect_ratio() {
    local width=$1
    local height=$2
    awk "BEGIN {printf \"%.6f\", $width/$height}"
}

# Function to parse size (handles presets and custom dimensions)
parse_size() {
    local size_spec=$1
    if [[ -n "${SIZE_PRESETS[$size_spec]}" ]]; then
        echo "${SIZE_PRESETS[$size_spec]}"
    else
        echo "$size_spec"
    fi
}

# Process images and get their info
declare -a IMAGE_FILES
declare -a IMAGE_WIDTHS  
declare -a IMAGE_HEIGHTS
declare -a TEMP_FILES

echo "Processing ${#IMAGES[@]} images for $PAPER_SIZE paper at ${DPI} DPI..."

for i in "${!IMAGES[@]}"; do
    IFS=':' read -r img_file size_spec <<< "${IMAGES[$i]}"
    
    # Check if image exists
    if [ ! -f "$img_file" ]; then
        echo "Error: Image '$img_file' not found!"
        exit 1
    fi
    
    # Parse size
    size=$(parse_size "$size_spec")
    width=$(echo "$size" | cut -d'x' -f1)
    height=$(echo "$size" | cut -d'x' -f2)
    
    # Validate dimensions
    if ! [[ "$width" =~ ^[0-9]*\.?[0-9]+$ ]] || ! [[ "$height" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "Error: Invalid size '$size_spec' for $img_file"
        echo "Use format like '4x6' or preset like 'wallet'"
        exit 1
    fi
    
    IMAGE_FILES[$i]="$img_file"
    IMAGE_WIDTHS[$i]="$width"
    IMAGE_HEIGHTS[$i]="$height"
    
    # Create processed image
    temp_file="temp_${i}_${width}x${height}.jpg"
    TEMP_FILES+=("$temp_file")
    
    # Calculate aspect ratio and crop accordingly
    target_ratio=$(calc_aspect_ratio "$width" "$height")
    
    echo "  Processing $img_file -> ${width}\"x${height}\" (ratio: $(printf "%.2f" "$target_ratio"))"
    
    # Calculate exact pixel dimensions for this image
    img_width_px=$(awk "BEGIN {printf \"%.0f\", $width * $DPI}")
    img_height_px=$(awk "BEGIN {printf \"%.0f\", $height * $DPI}")
    
    echo "    Target size: ${img_width_px}x${img_height_px} pixels"
    
    magick "$img_file" -gravity center -crop "${target_ratio}:1" +repage \
           -resize "${img_width_px}x${img_height_px}!" -density $DPI -units PixelsPerInch "$temp_file"
    
    # Check if temp file was created successfully
    if [ -f "$temp_file" ]; then
        file_size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
        echo "    ✓ Created $temp_file (${file_size} bytes)"
    else
        echo "    ✗ Failed to create $temp_file"
        exit 1
    fi
done

# Calculate paper dimensions in pixels
PAPER_WIDTH=$(echo "$PAPER_DIMS" | cut -d'x' -f1)
PAPER_HEIGHT=$(echo "$PAPER_DIMS" | cut -d'x' -f2)

# Handle orientation forcing
if [[ "$FORCE_ORIENTATION" == "landscape" ]] && (( $(awk "BEGIN {print ($PAPER_WIDTH < $PAPER_HEIGHT)}") )); then
    # Swap dimensions for landscape
    temp=$PAPER_WIDTH
    PAPER_WIDTH=$PAPER_HEIGHT
    PAPER_HEIGHT=$temp
elif [[ "$FORCE_ORIENTATION" == "portrait" ]] && (( $(awk "BEGIN {print ($PAPER_WIDTH > $PAPER_HEIGHT)}") )); then
    # Swap dimensions for portrait
    temp=$PAPER_WIDTH
    PAPER_WIDTH=$PAPER_HEIGHT
    PAPER_HEIGHT=$temp
fi

PAPER_WIDTH_PX=$(awk "BEGIN {printf \"%.0f\", $PAPER_WIDTH * $DPI}")
PAPER_HEIGHT_PX=$(awk "BEGIN {printf \"%.0f\", $PAPER_HEIGHT * $DPI}")
MARGIN_PX=$(awk "BEGIN {printf \"%.0f\", $MARGIN * $DPI}")
SPACING_PX=$(awk "BEGIN {printf \"%.0f\", $SPACING * $DPI}")

echo ""
echo "Layout calculations:"
echo "  Paper: ${PAPER_WIDTH}\" x ${PAPER_HEIGHT}\" (${PAPER_WIDTH_PX}x${PAPER_HEIGHT_PX} px)"
echo "  Margin: ${MARGIN}\" (${MARGIN_PX} px)"
echo "  Spacing: ${SPACING}\" (${SPACING_PX} px)"

# Smart positioning algorithm
available_width=$((PAPER_WIDTH_PX - 2 * MARGIN_PX))
available_height=$((PAPER_HEIGHT_PX - 2 * MARGIN_PX))

declare -a POSITIONS_X
declare -a POSITIONS_Y

current_x=$MARGIN_PX
current_y=$MARGIN_PX
row_height=0

echo ""
echo "Positioning images:"

for i in "${!IMAGE_FILES[@]}"; do
    img_width_px=$(awk "BEGIN {printf \"%.0f\", ${IMAGE_WIDTHS[$i]} * $DPI}")
    img_height_px=$(awk "BEGIN {printf \"%.0f\", ${IMAGE_HEIGHTS[$i]} * $DPI}")
    
    # Check if image fits in current row
    if (( current_x + img_width_px > PAPER_WIDTH_PX - MARGIN_PX && current_x > MARGIN_PX )); then
        # Move to next row
        current_x=$MARGIN_PX
        current_y=$((current_y + row_height + SPACING_PX))
        row_height=0
    fi
    
    # Check if image fits on page at all
    if (( current_y + img_height_px > PAPER_HEIGHT_PX - MARGIN_PX )); then
        echo "  Warning: Image $((i+1)) (${IMAGE_FILES[$i]}) may not fit on page!"
    fi
    
    POSITIONS_X[$i]=$current_x
    POSITIONS_Y[$i]=$current_y
    
    echo "  Image $((i+1)): ${IMAGE_FILES[$i]} at ($(awk "BEGIN {printf \"%.1f\", $current_x/$DPI}")\", $(awk "BEGIN {printf \"%.1f\", $current_y/$DPI}")\")"
    
    # Update position for next image
    current_x=$((current_x + img_width_px + SPACING_PX))
    if (( img_height_px > row_height )); then
        row_height=$img_height_px
    fi
done

# Create the final layout
OUTPUT_NAME="${OUTPUT_PREFIX}_${PAPER_SIZE}_${#IMAGES[@]}images.jpg"

echo ""
echo "Creating final layout..."

# Build magick command arguments in an array
magick_args=()
magick_args+=("-size" "${PAPER_WIDTH_PX}x${PAPER_HEIGHT_PX}")
magick_args+=("-density" "$DPI")
magick_args+=("xc:white")

for i in "${!TEMP_FILES[@]}"; do
    magick_args+=("${TEMP_FILES[$i]}")
    magick_args+=("-geometry" "+${POSITIONS_X[$i]}+${POSITIONS_Y[$i]}")
    magick_args+=("-composite")
done

magick_args+=("$OUTPUT_NAME")

# Execute the command
echo "Running: magick ${magick_args[*]}"
magick "${magick_args[@]}"

# Check if the command succeeded
if [ $? -eq 0 ]; then
    echo "✓ Magick command completed successfully"
else
    echo "✗ Magick command failed"
    exit 1
fi

# Clean up temporary files
for temp_file in "${TEMP_FILES[@]}"; do
    rm -f "$temp_file"
done

echo ""
echo "✓ Layout created: $OUTPUT_NAME"
echo "✓ Paper: $PAPER_SIZE (${PAPER_WIDTH}\"×${PAPER_HEIGHT}\")"
echo "✓ Resolution: ${DPI} DPI"
echo "✓ Images: ${#IMAGES[@]} positioned with ${MARGIN}\" margins, ${SPACING}\" spacing"
echo ""
echo "Print settings:"
echo "  - Print at actual size (100% scale)"
echo "  - Use high quality/photo paper settings"
echo "  - Color management: sRGB"
