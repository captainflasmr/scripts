#!/bin/bash

# Directory to store the .desktop files
output_dir="/home/jdyer/.local/share/file-manager/actions"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# # List of application names
# apps=(
#     PictureConvert
#     PictureInfo
#     PictureRotateLeft
#     PictureRotateRight
#     PictureScale
#     PictureAutoColour
#     PictureCrush
#     PictureMontage
#     PictureRotateFlip
#     PictureUpscale
#     PictureGetText
#     PictureOrientation
#     PictureCorrect
#     Picture2pdf
# )

# apps=(
#    AudioConvert
#    AudioNormalise
#    AudioTrimSilence
#    AudioInfo
# )

apps=(
   TouchABit
   WhatsAppConvert
   PictureOrganise
   ConvertNoSpace
   OtherTagDate
   )

# apps=(
#    VideoInfo
#    VideoConcat
#    VideoConvert
#    VideoCut
#    VideoDouble
#    VideoExtractAudio
#    VideoExtractFrames
#    VideoFilter
#    VideoFromFrames
#    VideoRemoveAudio
#    VideoReplaceAudio
#    VideoReplaceVideoAudio
#    VideoRescale
#    VideoReverse
#    VideoRotate
#    VideoRotateLeft
#    VideoRotateRight
#    VideoShrink
#    VideoSlowDown
#    VideoSpeedUp
#    VideoZoom
# )

# Template for the .desktop file
template="[Desktop Entry]
Type=Action
Profiles=profile_id
Name=%s
Name[cc]=%s
Icon=

[X-Action-Profile profile_id]
MimeTypes=all/all;
Exec=ServiceConsole %s %%F
"

# Generate the .desktop files
for app in "${apps[@]}"; do
    # Format the template with the application name
    content=$(printf "$template" "$app" "$app" "$app")

    # Define the filename
    filename="$output_dir/${app}.desktop"

    # Write the content to the file
    echo "$content" > "$filename"
done

echo
echo "Desktop files have been generated in the '$output_dir' directory."
echo
