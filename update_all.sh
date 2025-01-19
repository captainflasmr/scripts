#!/bin/bash
# Enhanced Script to automate the organisation and tagging of images and videos

clear

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
    echo "========== TAGGING MENU =========="
    echo "1. Tag images"
    echo "2. Tag videos"
    echo "3. Both"
    read -p "Enter your choice: " CHOICE

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
        q)
            echo "Skipping tagging operations."
            ;;
        *)
            echo "Invalid choice. Skipping tagging."
            ;;
    esac
}

# Menu for syncing content to devices and webpages
sync_content() {
    echo "========== SYNCING MENU =========="
    echo "1. Sync and compress images"
    echo "2. Sync videos"
    echo "3. Sync to NAS"
    echo "4. Sync to Web"
    echo "5. Run all operations"
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1)
            echo "Running images.sh..."
            run_command images.sh
            ;;
        2)
            echo "Running videos.sh..."
            run_command videos.sh
            ;;
        3)
            echo "Running mysync..."
            run_command mysync --photos out
            ;;
        4)
            echo "Running mysync..."
            run_command web update dyerdwelling
            ;;
        5)
            echo "Running all syncing and categorisation scripts..."
            run_command images.sh
            run_command images_cat.sh
            run_command videos.sh
            ;;
        q)
            echo "Skipping syncing operations."
            ;;
        *)
            echo "Invalid choice. Skipping syncing."
            ;;
    esac
}

SRC_DIR="/run/media/jdyer/7FBD-D459/Photos/2025"
validate_directory "$SRC_DIR"
cd "$SRC_DIR"

# Main Script
while true; do
    echo "========== MAIN MENU =========="
    echo "1. Tag"
    echo "2. Sync"
    read -p "Enter your choice: " MAIN_CHOICE

    case $MAIN_CHOICE in
        1)
            tag_photos_and_videos
            ;;
        2)
            sync_content
            ;;
        q)
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
