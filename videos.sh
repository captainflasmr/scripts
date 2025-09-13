#!/bin/bash
# Resize any video directory named by SRC and send to DST ready to upload to my Web Site!

PHOTOS_SRC="/mnt/local/Photos"
PARALLEL_JOBS=$(($(nproc) / 2))  # Use half the cores for video processing

function resize_videos() {
    cd "$SRC"
    mkdir -p "$DST"
    
    # Function to process a single video file
    process_single_video() {
        local A="$1"
        local DST="$2"
        
        source Common.sh
        
        pre
        
        if [[ ! -f "$DST/${FILE}" ]]; then
            printf "$DST/${FILE} \n"
            
            # Maintain aspect ratio while scaling
            ffmpeg -hide_banner -loglevel panic -stats -y -i "$A" \
                   -vf "scale='min(960,iw)':'min(480,ih)':force_original_aspect_ratio=decrease" \
                   -threads 1 -vcodec libx264 -crf 28 "$DST/${FILE}"
            
            SIZE=$(du "$DST/${FILE}" 2>/dev/null | cut -f 1 || echo "0")
            if [[ $SIZE == 0 ]]; then
                echo "ZERO GENERATED for $A - Retrying!!!!"
                ffmpeg -hide_banner -loglevel panic -stats -y -i "$A" \
                       -vf "scale='min(960,iw)':'min(480,ih)':force_original_aspect_ratio=decrease" \
                       -threads 1 -vcodec libx264 -crf 23 "$DST/${FILE}"
            fi
            
            touch -r "$A" "$DST/${FILE}"
        fi
    }
    
    export -f process_single_video
    
    echo "Processing videos in parallel with $PARALLEL_JOBS cores..."
    
    find "$SRC" \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.mp4' -print0 | \
        xargs -0 -I {} -P "$PARALLEL_JOBS" -n 1 \
              bash -c 'process_single_video "$1" "$2"' _ {} "$DST"
}

for DIR in {2023..2025}; do
    echo
    echo "Processing Videos $DIR ..."
    echo
    SRC="${PHOTOS_SRC}/${DIR}"
    DST="$HOME/DCIM/Videos/${DIR}"
    
    if [[ -d "$SRC" ]]; then
        resize_videos
    else
        echo "Warning: $SRC does not exist, skipping..."
    fi
done
