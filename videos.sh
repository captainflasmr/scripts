#! /bin/bash
# Resize any video directory named by SRC and send to DST ready to upload to my Web Site!

PHOTOS_SRC="/run/media/jdyer/7FBD-D459/Photos"

function resize_videos() {
    cd $SRC
    FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.mp4' -printf '%p;')
    source Common.sh $FILES
    mkdir -p "$DST"
    for A in $FILES; do
        pre
        if [[ ! -f "$DST/${FILE}" ]]; then
            printf "$DST/${FILE} \n"
            # ffmpeg -hide_banner -loglevel panic -stats -y -i "$A" -vf "scale=480x240" -threads 8 -vcodec libx264 -crf 28 "$DST/${FILE}"
            ffmpeg -hide_banner -loglevel panic -stats -y -i "$A" -vf "scale=960x480" -threads 8 -vcodec libx264 -crf 28 "$DST/${FILE}"
            SIZE=$(du "$DST/${FILE}" | cut -f 1)
            if [[ $SIZE == 0 ]]; then
                echo "ZERO GENERATED!!!!"
                ffmpeg -hide_banner -loglevel panic -stats -y -i "$A" -threads 8 -vcodec libx264 -crf 23 "$DST/${FILE}"
            fi
            touch -r "$A" "$DST/${FILE}"
        fi
    done
    # delete any empty directories
    #    find "$DST" -type d -empty -delete
}

for DIR in {2023..2025}; do
    echo
    echo "Processing Videos $DIR ..."
    echo
    SRC="${PHOTOS_SRC}/${DIR}"
    DST="$HOME/DCIM/Videos/${DIR}"
    # rm -fr $DST/*.mp4
    resize_videos
done
