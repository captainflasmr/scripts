#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# upscale_art.sh — batch AI upscaling for the digital art pipeline
#
# Wraps the headless CLI bundled with the Upscayl AppImage (upscayl-bin).
# Recursively walks a source directory, upscales every image with the chosen
# model, resizes it to a target SHORT edge (default 7632px for Redbubble) and
# mirrors the folder structure into the destination.
#
# Verified on this machine: upscayl-appimage 2.15.0, digital-art-4x model,
# Vulkan GPU (Intel HD 620).
#
# USAGE
#   upscale_art.sh [options] <input_dir> [output_dir]
#
# OPTIONS
#   -m MODEL     model name (default: digital-art-4x)
#   -e EDGE      target SHORT edge in px (default: 7632). A 7632px short edge
#                covers Redbubble duvets/tapestries (6480x7632) and
#                photographic prints XL (6096x9144) in either orientation.
#                0 = native model scale (4x), no resize.
#   -f FORMAT    output format: jpg | png | webp (default: jpg)
#   -c N         compression 0-100 (default: 0 = best quality)
#   -g GPU       GPU id, e.g. 0 (default: auto)
#   -t TILE      tile size >= 32, 0 = auto (default: auto)
#   --force      re-upscale outputs that already exist
#   --dry-run    print what would run, do not process
#   --list-models  list bundled model names and exit
#   -h           show this help
#
# ENV
#   UPSCAYL_BIN  override path to upscayl-bin
#   MODELS_DIR   override models folder
#
# AFTER UPSCALING
#   ~/bin/normalize_art.sh <output_dir> ~/Downloads/normalized_art
# ============================================================================

UPSCAYL_BIN="${UPSCAYL_BIN:-/opt/upscayl/resources/bin/upscayl-bin}"
MODELS_DIR="${MODELS_DIR:-/opt/upscayl/resources/models}"

MODEL="digital-art-4x"
EDGE=7632
FORMAT="jpg"
COMPRESSION=0
GPU=""
TILE=""
FORCE=0
DRYRUN=0

usage() { sed -n '3,40p' "$0" | sed 's/^# \{0,1\}//'; }

list_models() {
    local p
    for p in "$MODELS_DIR"/*.param; do
        [[ -e "$p" ]] || { echo "No models found in $MODELS_DIR" >&2; return 1; }
        basename "$p" .param
    done
}

while (( $# )); do
    case "$1" in
        -m) MODEL="$2"; shift 2 ;;
        -e) EDGE="$2"; shift 2 ;;
        -f) FORMAT="$2"; shift 2 ;;
        -c) COMPRESSION="$2"; shift 2 ;;
        -g) GPU="$2"; shift 2 ;;
        -t) TILE="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --dry-run) DRYRUN=1; shift ;;
        --list-models) list_models; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) break ;;
    esac
done

SRC="${1:-}"
DEST="${2:-./upscaled_art}"

[[ -n "$SRC" ]] || { echo "Error: no input directory given." >&2; usage >&2; exit 1; }
[[ -d "$SRC" ]] || { echo "Error: not a directory: $SRC" >&2; exit 1; }
[[ -x "$UPSCAYL_BIN" ]] || { echo "Error: upscayl-bin not found at $UPSCAYL_BIN" >&2; echo "Set UPSCAYL_BIN or install the upscayl-appimage package." >&2; exit 1; }
[[ -f "$MODELS_DIR/$MODEL.param" ]] || {
    echo "Error: model '$MODEL' not found in $MODELS_DIR" >&2
    echo "Available models:" >&2; list_models | sed 's/^/  /' >&2; exit 1
}
[[ "$FORMAT" =~ ^(jpg|png|webp)$ ]] || { echo "Error: format must be jpg, png or webp." >&2; exit 1; }
[[ "$EDGE" =~ ^[0-9]+$ ]] || { echo "Error: -e expects a number." >&2; exit 1; }

mkdir -p "$DEST"
SRC="$(cd "$SRC" && pwd)"
DEST="$(cd "$DEST" && pwd)"
LOG="$DEST/upscale.log"

echo "========================================"
echo "Upscayl batch upscale"
echo "========================================"
echo "Input:    $SRC"
echo "Output:   $DEST"
echo "Model:    $MODEL"
if (( EDGE > 0 )); then echo "Target:   short edge ${EDGE}px"; else echo "Target:   native model scale (4x)"; fi
echo "Format:   $FORMAT (compression $COMPRESSION)"
(( DRYRUN )) && echo "DRY RUN — nothing will be written"
echo "Log:      $LOG"
echo "----------------------------------------"

TOTAL=0; DONE=0; SKIPPED=0; FAILED=0
START=$SECONDS

while IFS= read -r -d '' img; do
    TOTAL=$((TOTAL + 1))
    rel="${img#"$SRC"/}"
    out="$DEST/${rel%.*}.$FORMAT"

    if [[ -e "$out" && $FORCE -eq 0 ]]; then
        echo "skip (exists): $rel"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    mkdir -p "$(dirname "$out")"
    read -r w h < <(magick identify -format '%w %h\n' "$img")

    args=( -i "$img" -o "$out" -n "$MODEL" -m "$MODELS_DIR" -f "$FORMAT" -c "$COMPRESSION" )
    tw=""
    if (( EDGE > 0 )); then
        if (( w >= h )); then tw=$(( (EDGE * w + h - 1) / h )); else tw=$EDGE; fi
        args+=( -w "$tw" )
    fi
    [[ -n "$GPU" ]]  && args+=( -g "$GPU" )
    [[ -n "$TILE" ]] && args+=( -t "$TILE" )

    echo "[$((DONE + SKIPPED + FAILED + 1))/$TOTAL] $rel  (${w}x${h} → width ${tw:-model})"
    if (( DRYRUN )); then
        printf '  '; printf '%q ' "$UPSCAYL_BIN" "${args[@]}"; echo
        continue
    fi

    echo "[$(date '+%F %T')] $UPSCAYL_BIN ${args[*]}" >>"$LOG"
    if "$UPSCAYL_BIN" "${args[@]}" >>"$LOG" 2>&1; then
        read -r ow oh < <(magick identify -format '%w %h\n' "$out")
        echo "  ✓ ${ow}x${oh}"
        DONE=$((DONE + 1))
    else
        echo "  ✗ failed — see $LOG"
        FAILED=$((FAILED + 1))
    fi
done < <(find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -not -path "$DEST/*" -print0)

ELAPSED=$((SECONDS - START))
echo "----------------------------------------"
printf 'Done: %d processed, %d skipped, %d failed of %d (%dm%02ds)\n' \
    "$DONE" "$SKIPPED" "$FAILED" "$TOTAL" "$((ELAPSED / 60))" "$((ELAPSED % 60))"
echo "Next: ~/bin/normalize_art.sh \"$DEST\" ~/Downloads/normalized_art"

if (( FAILED > 0 )); then exit 2; fi
