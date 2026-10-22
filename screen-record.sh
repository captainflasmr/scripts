#!/bin/bash
#
# Toggle screen recording.
#
# On Wayland a short layer-shell overlay is shown above everything (including
# fullscreen windows) before wf-recorder starts.  The overlay exits before the
# first frame is grabbed, so it is never part of the recording.  A "saved"
# overlay is shown after the recorder has finished writing the file.
#
# Environment overrides:
#   RECORD_DIR           output directory             (default: ~/Videos)
#   RECORD_COUNTDOWN     countdown seconds, 0 = off   (default: 3)
#   RECORD_AUDIO_DEVICE  PulseAudio/PipeWire source   (default: USB monitor)
#   RECORD_OVERLAY       overlay helper               (default: ~/bin/recording-overlay.py)

DATE=$(date +%Y%m%d%H%M%S)
DST="${RECORD_DIR:-$HOME/Videos}"
COUNTDOWN="${RECORD_COUNTDOWN:-3}"
AUDIO_DEVICE="${RECORD_AUDIO_DEVICE:-alsa_output.usb-Synaptics_Hi-Res_Audio_000000000000000000000000-00.analog-stereo.monitor}"
OVERLAY="${RECORD_OVERLAY:-$HOME/bin/recording-overlay.py}"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_DIR="$RUNTIME_DIR/screen-record-$(id -u)"
STATE="$STATE_DIR/state"
LOG="$STATE_DIR/wf-recorder.log"
START_LOCK="$STATE_DIR/start.lock"
STOP_MARKER="$STATE_DIR/stop-requested"

mkdir -p "$DST" "$STATE_DIR"

overlay() {
    # A missing or broken overlay must never prevent recording.  Kill any
    # previous overlay first so a new message/countdown replaces it cleanly.
    if [[ -x "$OVERLAY" ]]; then
        pkill -f -- "recording-overlay.py --mode" 2>/dev/null || true
        timeout 30 "$OVERLAY" "$@" >/dev/null 2>&1 || true
    fi
}

wf_running() {
    pgrep -x wf-recorder >/dev/null 2>&1
}

fmt_duration() {
    local seconds="${1:-0}"
    (( seconds < 0 )) && seconds=0
    printf '%02d:%02d' $((seconds / 60)) $((seconds % 60))
}

show_saved() {
    local file="$1" start="${2:-}"
    local body size duration

    body=$(basename "$file")
    if [[ -n "$start" ]]; then
        duration=$(fmt_duration $(( $(date +%s) - start )))
        body+="  ·  $duration"
    fi
    size=$(du -h "$file" 2>/dev/null | cut -f1)
    [[ -n "$size" ]] && body+="  ·  $size"

    overlay --mode message --icon "✓" --title "Recording saved" \
        --body "$body" --accent "#a3be8c" --timeout-ms 4500
}

show_error() {
    local title="${1:-Recording problem}" message="${2:-}"
    message="${message//$'\n'/ }"
    overlay --mode message --icon "⚠" --title "$title" \
        --body "$message" --accent "#bf616a" --timeout-ms 8000
}

wayland_start() {
    local file="$DST/$DATE--screen-recording.mkv"
    local start_epoch rec_pid err

    # Prevent a second countdown/start if the shortcut is pressed twice.
    # flock is released automatically if this script is interrupted.
    exec 9>"$START_LOCK"
    if ! flock -n 9; then
        exec 9>&-
        return 0
    fi
    rm -f "$STOP_MARKER"

    if [[ "$COUNTDOWN" =~ ^[0-9]+$ ]] && (( COUNTDOWN > 0 )); then
        overlay --mode countdown --seconds "$COUNTDOWN"
        # Let the compositor paint the frame without the overlay before
        # wf-recorder grabs its first frame.
        sleep 0.35
    fi

    start_epoch=$(date +%s)
    printf 'REC_FILE=%q\nREC_START=%q\nREC_OWNER=%q\n' \
        "$file" "$start_epoch" "$$" > "$STATE.tmp"
    mv -f "$STATE.tmp" "$STATE"
    : > "$LOG"

    wf-recorder \
        --audio="$AUDIO_DEVICE" \
        -f "$file" -F fps=5 >"$LOG" 2>&1 &
    rec_pid=$!

    # Ctrl+C in the invoking terminal should finalise the file, not leave a
    # half-written recording behind.
    trap 'kill -INT "$rec_pid" 2>/dev/null' INT TERM

    # Release the start lock only after the recorder exists, so a very fast
    # second keypress is treated as "stop" rather than starting another one.
    flock -u 9
    exec 9>&-

    while kill -0 "$rec_pid" 2>/dev/null; do
        wait "$rec_pid" 2>/dev/null || true
    done
    wait "$rec_pid" 2>/dev/null || true
    trap - INT TERM

    if [[ -e "$STOP_MARKER" ]]; then
        # The process that stopped us shows the "saved" overlay once the file
        # has been finalised.
        rm -f "$STATE"
        return 0
    fi

    if [[ -s "$file" ]]; then
        show_saved "$file" "$start_epoch"
        rm -f "$STATE"
        return 0
    fi

    err=$(tail -n 1 "$LOG" 2>/dev/null || true)
    show_error "Recording failed" "${err:-wf-recorder did not write a file}"
    rm -f "$STATE"
    return 1
}

wayland_stop() {
    local file="" start="" waited=0

    if [[ -r "$STATE" ]]; then
        # shellcheck disable=SC1090
        . "$STATE"
        file="${REC_FILE:-}"
        start="${REC_START:-}"
    fi

    : > "$STOP_MARKER"
    if ! pkill -INT -x wf-recorder; then
        rm -f "$STOP_MARKER"
        return 0
    fi

    # wf-recorder finalises the container on SIGINT.  Wait for it so the
    # "saved" overlay reports the finished file accurately.
    while pgrep -x wf-recorder >/dev/null 2>&1; do
        (( waited++ ))
        if (( waited >= 150 )); then
            rm -f "$STOP_MARKER"
            show_error "Recording not stopped" "wf-recorder is still running"
            return 1
        fi
        sleep 0.1
    done

    if [[ -n "$file" ]]; then
        if [[ -s "$file" ]]; then
            show_saved "$file" "$start"
        else
            show_error "Recording failed" "No output file was written"
        fi
    else
        overlay --mode message --icon "✓" --title "Recording stopped" \
            --body "No recording file was tracked for this session" \
            --accent "#a3be8c" --timeout-ms 3500
    fi

    rm -f "$STATE" "$STATE.tmp" "$STOP_MARKER"
    return 0
}

x11_toggle() {
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
}

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    if wf_running; then
        wayland_stop
    else
        wayland_start
    fi
else
    x11_toggle
fi
