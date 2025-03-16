#!/bin/bash
DATE=$(date +%Y%m%d%H%M%S)
DST=~/Videos

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
    # Note : to get the audio device run: pactl list sources
    # | grep -i "Name" and choose the first line staring with
    # Name which will be the very long name!  oh and if you
    # are not sure which audio device is coming out of then
    # use pavucontrol
    pid=`pgrep wf-recorder`
    # pid=`pgrep wl-screenrec`
    status=$?

    if [[ $status != 0 ]]; then
        wf-recorder \
            --audio="alsa_output.usb-Synaptics_Hi-Res_Audio_000000000000000000000000-00.analog-stereo.monitor" \
            -f "$DST"/$DATE--screen-recording.mkv -F fps=5
        # wl-screenrec \
            # -f "$DST"/$DATE--screen-recording.mkv
    else
        pkill --signal SIGINT wf-recorder
        # pkill --signal SIGINT wl-screenrec
    fi;
else
    # Check if ffmpeg is already running
    pid=$(pgrep ffmpeg)
    status=$?

    # Cleanup function to terminate ffmpeg gracefully
    cleanup() {
        echo "Stopping screen recording..."
        pkill -SIGTERM ffmpeg
        while pgrep ffmpeg > /dev/null; do
            sleep 1
        done
        echo "Screen recording stopped."
    }
    trap cleanup EXIT

    if [[ $status != 0 ]]; then
        # Ensure the output directory exists
        mkdir -p "$DST"

        # Start recording
        echo "Starting screen recording..."
        ffmpeg -video_size 1920x1080 -framerate 10 \
               -f x11grab -i :0.0+0,0 \
               -c:v libx264rgb -preset ultrafast -crf 23 -pix_fmt yuv420p \
               -movflags +faststart \
               "$DST"/"$DATE"--screen-recording.mkv 2> "$DST"/"$DATE--screen-recording.log"
    else
        # Stop recording gracefully
        cleanup
    fi
fi
