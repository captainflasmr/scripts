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

# Function to clean a directory of jpg files
clean_directory() {
    local base_dir="$1"
    local dir_name="$2"
    
    if [[ ! -d "$base_dir" ]]; then
        echo "Warning: $dir_name directory '$base_dir' does not exist. Skipping."
        return
    fi
    
    echo "Cleaning .jpg files from subdirectories in $base_dir"
    
    # Find subdirectories only (not the base directory)
    for dir in $(find "$base_dir" -mindepth 1 -type d); do
        echo "Deleting from $dir"
        cd "$dir"
        rm -fr *.jpg 2>/dev/null || true  # Suppress errors if no jpg files found
    done
    
    echo "$dir_name cleanup completed."
}

# Function to clean tagged directory
clean_tagged_directory() {
    echo "========== CLEANING TAGGED DIRECTORY =========="
    clean_directory "$HOME/DCIM/content/tagged" "Tagged directory"
}

# Function to clean all image destination directories
clean_image_destinations() {
    echo "========== CLEANING IMAGE DESTINATION DIRECTORIES =========="
    
    # Clean art gallery directories
    echo "Cleaning art gallery directories..."
    clean_directory "$HOME/DCIM/content/art--gallery" "Art gallery"
    
    # Clean scans directories
    echo "Cleaning scans directories..."
    clean_directory "$HOME/DCIM/content/scans" "Scans"
    
    # Clean photos directories (by year)
    echo "Cleaning photos directories..."
    photos_base="$HOME/DCIM/content/photos"
    if [[ -d "$photos_base" ]]; then
        for year_dir in $(find "$photos_base" -mindepth 1 -maxdepth 1 -type d); do
            echo "Cleaning photos for year: $(basename $year_dir)"
            cd "$year_dir"
            rm -fr *.jpg 2>/dev/null || true
        done
        echo "Photos directories cleanup completed."
    else
        echo "Warning: Photos directory '$photos_base' does not exist. Skipping."
    fi
    
    echo "All image destination directories cleaned."
}

# Function to clean all content directories
clean_all_content() {
    echo "========== CLEANING ALL CONTENT DIRECTORIES =========="
    clean_tagged_directory
    clean_image_destinations
    echo "All content directories cleaned."
}

# Menu for cleaning operations
cleaning_menu() {
    echo "========== CLEANING MENU =========="
    echo "1. Clean tagged directory only"
    echo "2. Clean image destinations only"
    echo "3. Clean all content directories"
    echo "q. Return to main menu"
    read -p "Enter your choice: " CLEAN_CHOICE

    case $CLEAN_CHOICE in
        1)
            clean_tagged_directory
            ;;
        2)
            clean_image_destinations
            ;;
        3)
            clean_all_content
            ;;
        q)
            echo "Returning to main menu."
            ;;
        *)
            echo "Invalid choice. Returning to main menu."
            ;;
    esac
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

SRC_DIR="/mnt/local/Photos/2025"
validate_directory "$SRC_DIR"
cd "$SRC_DIR"

# Main Script
while true; do
    echo "========== MAIN MENU =========="
    echo "1. Tag"
    echo "2. Sync"
    echo "3. Clean"
    echo "4. Regenerate"
    read -p "Enter your choice: " MAIN_CHOICE

    case $MAIN_CHOICE in
        1)
            tag_photos_and_videos
            ;;
        2)
            sync_content
            ;;
        3)
            cleaning_menu
            ;;
        4)
            echo "Running tagged_thumbnail_update.sh..."
            cd $HOME/DCIM/content/tagged
            run_command tagged_thumbnail_update.sh
            ;;
        q)
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
