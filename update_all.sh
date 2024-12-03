#!/bin/bash

# Enhanced Script to automate the organisation and tagging of images and videos
#
# Features:
# - Dynamic Inputs
# - Error Handling
# - User Interactivity
# - Menu-driven flexibility

clear
echo "============ IMAGE & VIDEO ORGANISATION SCRIPT ============"
echo 

# Function to validate if a directory exists
validate_directory() {
    if [[ ! -d $1 ]]; then
        echo "Error: Directory '$1' does not exist. Exiting."
        exit 1
    fi
}

# Function to run commands and handle missing dependencies
run_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Command '$1' not found. Please install it."
        exit 1
    else
        "$@" # Run the command if it exists
    fi
}

# Menu for tagging operations
tag_photos_and_videos() {
    echo
    echo "========== TAGGING MENU =========="
    echo "1. Tag images"
    echo "2. Tag videos"
    echo "3. Both"
    echo "4. Skip tagging"
    echo "Enter your choice:"
    read -r CHOICE

    case $CHOICE in
        1)
            echo "Running tag_image_out.sh..."
            run_command tag_image_out.sh
            ;;
        2)
            echo "Running tag_video_out.sh..."
            run_command tag_video_out.sh
            ;;
        3)
            echo "Running tag_image_out.sh and tag_video_out.sh..."
            run_command tag_image_out.sh
            run_command tag_video_out.sh
            ;;
        4)
            echo "Skipping tagging operations."
            ;;
        *)
            echo "Invalid choice. Skipping tagging."
            ;;
    esac
}

# Menu for syncing content to devices and webpages
sync_content() {
    echo
    echo "========== SYNCING MENU =========="
    echo "1. Sync and compress images"
    echo "2. Categorise images"
    echo "3. Sync videos"
    echo "4. Sync to NAS"
    echo "5. Sync to Web"
    echo "6. Run all operations"
    echo "7. Skip syncing"
    echo "Enter your choice:"
    read -r CHOICE

    case $CHOICE in
        1)
            echo "Running images.sh..."
            run_command images.sh
            ;;
        2)
            echo "Running images_cat.sh..."
            run_command images_cat.sh
            ;;
        3)
            echo "Running videos.sh..."
            run_command videos.sh
            ;;
        4)
            echo "Running mysync..."
            run_command mysync --photos out
            ;;
        5)
            echo "Running mysync..."
            run_command web update dyerdwelling
            ;;
        6)
            echo "Running all syncing and categorisation scripts..."
            run_command images.sh
            run_command images_cat.sh
            run_command videos.sh
            ;;
        7)
            echo "Skipping syncing operations."
            ;;
        *)
            echo "Invalid choice. Skipping syncing."
            ;;
    esac
}

SRC_DIR="/run/media/jdyer/7FBD-D459/Photos/2024"
validate_directory "$SRC_DIR"
cd "$SRC_DIR"

# Main Script
while true; do
    echo
    echo "========== MAIN MENU =========="
    echo "1. Tag To Filename"
    echo "2. Sync Content"
    echo "3. Exit"
    echo "Enter your choice:"
    read -r MAIN_CHOICE

    case $MAIN_CHOICE in
        1)
            tag_photos_and_videos
            ;;
        2)
            sync_content
            ;;
        3)
            echo "Exiting. Goodbye!"
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
