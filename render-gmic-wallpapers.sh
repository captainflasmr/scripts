#!/usr/bin/env bash

set -Eeuo pipefail

source_dir=${1:-Gallery}
output_dir=${2:-wallpaper-gmic-textured-glass-hd}
jobs=${JOBS:-2}

if [[ ! -d "$source_dir" ]]; then
    printf 'Source directory does not exist: %s\n' "$source_dir" >&2
    exit 1
fi

if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    printf 'JOBS must be a positive integer.\n' >&2
    exit 1
fi

render_wallpaper() {
    local input=$1
    local relative=${input#"$source_dir"/}
    local output="$output_dir/${relative%.*}.jpg"
    local output_parent
    local output_temp

    if [[ -e "$output" ]]; then
        printf 'Skipping existing wallpaper: %s\n' "$output"
        return
    fi

    output_parent=$(dirname "$output")
    mkdir -p "$output_parent"
    output_temp="$output_parent/.${output##*/}.tmp.jpg"

    magick "$input" -auto-orient -strip -colorspace sRGB \
           -resize '1920x1080^' -gravity center -extent 1920x1080 \
           -quality 94 "$output_temp"

    # -------------------------------------------------------------------------
    # 2. KUWAHARA (Native, edge-preserving block painterly filter)
    # -------------------------------------------------------------------------
    # Arguments: [pixel_radius]
    # - 50 : Size of the analysis window. Larger numbers heavily group nearby pixels 
    #        into flat, painterly "oil-paint" blobs while aggressively protecting clean edges.
    # gmic -v 0 "$output_temp" \
        #     kuwahara 50 \
        #     output "$output_temp",94

    # -------------------------------------------------------------------------
    # 3. SMOOTH (Native anisotropic diffusion / "Dreamy Painterly")
    # -------------------------------------------------------------------------
    # Arguments: [amplitude],[sharpness],[anisotropy],[alpha],[sigma]
    # - 30  : Amplitude (strength of the overall smoothing run).
    # - 0.1 : Edge sharpness. Lower values blur the transitions, higher keeps boundaries hard.
    # - 0.8 : Anisotropy factor (closeness to 1.0 means it blurs strictly along lines/curves).
    # - 1   : Alpha (noise/texture scale factor).
    # - 4   : Sigma (spatial scale factor for pixel evaluation).
    # gmic -v 0 "$output_temp" \
        # smooth 300,0.2,0.8,1,4 \
        # output "$output_temp",94
    
    # -------------------------------------------------------------------------
    # 4. POLYGONIZE (Native geometric mesh stylization)
    # -------------------------------------------------------------------------
    # Arguments: [warp_amplitude],[smoothness],[min_area],[resolution_x],[resolution_y]
    # - 300 : Warp amplitude (distortion strength on the source details).
    # - 2   : Smoothness percentage.
    # - 0.1 : Minimum area percentage of generated polygon shapes.
    # - 10  : Horizontal mesh resolution density percentage.
    # - 10  : Vertical mesh resolution density percentage.
    # gmic -v 0 "$output_temp" \
        #     polygonize 300,2,0.1,10,10 \
        #     output "$output_temp",94

    # -------------------------------------------------------------------------
    # 5. QUANTIZE (Native K-Means color mapping / Flat Palette)
    # -------------------------------------------------------------------------
    # Arguments: [nb_levels],[keep_values],[quantization_type]
    # - 8 : Number of target colors. Compresses the entire image down to just these 8 tones.
    # - 1 : Keep original pixel scale values (1 = Yes, 0 = Index indices).
    # - 0 : Quantization type (0 = K-Means, which groups natural image palettes beautifully).
    # gmic -v 0 "$output_temp" \
        # quantize 4,1,0 \
        # output "$output_temp",94

    # -------------------------------------------------------------------------
    # 6. CARTOON (Native black outlines + flat color quantization)
    # -------------------------------------------------------------------------
    # Arguments: [smoothness],[sharpening],[threshold],[thickness],[color_doping],[quantization]
    # - 5   : Local smoothness before outline processing.
    # - 150 : Edge sharpening level.
    # - 20  : Edge detection threshold (lower = more outline details).
    # - 0   : Outline thickness. Setting this to 0 skips the black outlines entirely.
    # - 1.5 : Color intensity/doping modifier.
    # - 6   : Quantization levels (number of flat color shades to compress the image into).
    gmic -v 0 "$output_temp" \
        cartoon 5,150,20,0,1.5,6 \
        output "$output_temp",94

    # -------------------------------------------------------------------------
    # 1. TEXTURED GLASS (Wrapper command)
    # -------------------------------------------------------------------------
    # Arguments: [tile_width],[tile_height],[sharpness],[depth],[refraction],[smoothness],[glass_type]
    # - 1200, 1200 : Size (in pixels) of each glass piece. Larger = less granular, chunkier glass.
    # - 5          : Sharpness of the tile boundaries.
    # - 3          : Relief depth (3D lighting severity on the glass seams).
    # - 0.5        : Refraction index (strength of detail bending/distortion inside each tile).
    # - 10         : Smoothness (how soft/blended the transitions are inside the tiles).
    # - 4          : Glass pattern type (1-4). 4 creates nice organic-looking plates.
    # gmic -v 0 "$output_temp" \
        # fx_textured_glass 400,400,5,3,0.5,10,4 \
        # output "$output_temp",94
    
    mv -- "$output_temp" "$output"
    printf 'Rendered: %s\n' "$output"
}

export source_dir output_dir
export -f render_wallpaper

mkdir -p "$output_dir"

rg --files -0 --iglob '*.{jpg,jpeg,png,webp,tif,tiff}' "$source_dir" |
    xargs -0 -r -n 1 -P "$jobs" bash -c 'render_wallpaper "$1"' _
