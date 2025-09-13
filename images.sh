#!/bin/bash

# PHOTOS_SRC="/run/media/jdyer/Backup/Photos"
PHOTOS_SRC="/mnt/local/Photos"

export IFS=";"

# Global variable to determine processing mode
ORGANIZATION_MODE="standard"  # Default to standard mode

function resize_images_standard() {
    cd "$SRC"
    mkdir -p "$DST"
    
    # Function to process a single file
    process_single_file() {
        local A="$1"
        local DST="$2"
        
        source Common.sh
        
        pre
        EXT=jpg
        NEWFILE="${DST}/${FILE_NO_EXT}.${EXT}"
        if [[ ! -f "${NEWFILE}" ]]; then
            printf "$A -> ${NEWFILE}\n"
            magick "$A" -auto-orient -strip -quality 40% -resize '768x>' -resize 'x768>' "${NEWFILE}"
            exiftool -overwrite_original -TagsFromFile "$A" "${NEWFILE}"  # Apply metadata
            touch -r "$A" "${NEWFILE}"
        fi
    }
    
    export -f process_single_file
    
    echo "Processing images in parallel with $(nproc) cores..."
    
    find "$SRC" \( -name "private" -type d -prune \) -o \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -print0 | \
        xargs -0 -I {} -P $(nproc) -n 1 \
              bash -c 'process_single_file "$1" "$2"' _ {} "$DST"
    
    cd -
}

function resize_images_tagged() {
    cd "$SRC"
    DST="$HOME/DCIM/content/tagged"
    mkdir -p "$DST"
    
    # Function to process a single file in tagged mode
    process_single_file_tagged() {
        local A="$1"
        local DST="$2"
        
        source Common.sh
        
        pre
        for key in $keyw; do
            EXT=jpg
            NEWFILE="${DST}/${key}/${FILE_NO_EXT}.${EXT}"
            mkdir -p "${DST}/${key}"
            touch "${DST}/${key}/.nomedia"  # Hidden .nomedia file
            if [[ ! -f "${NEWFILE}" ]]; then
                printf "$A -> ${NEWFILE}\n"
                magick "$A" -auto-orient -strip -quality 30% -resize '1024x>' -resize 'x1024>' "${NEWFILE}"
                touch -r "$A" "${NEWFILE}"
            fi
        done
    }
    
    export -f process_single_file_tagged
    
    echo "Processing images in parallel (tagged mode) with $(nproc) cores..."
    
    find "$SRC" \( -name "private" -type d -prune \) -o \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -print0 | \
        xargs -0 -I {} -P $(nproc) -n 1 \
              bash -c 'process_single_file_tagged "$1" "$2"' _ {} "$DST"
    
    cd -
}

function resize_images() {
    if [[ "$ORGANIZATION_MODE" == "tagged" ]]; then
        resize_images_tagged
    else
        resize_images_standard
    fi
}

function process_art() {
    LIST="doodles;animals;got;landscapes;monsters;portraits;stilllife;buffy;kate;misc;starwars;superhero;old"
    echo
    echo "Processing Art..."
    echo
    for DIR in $LIST; do
        echo "$DIR"
        SRC="${PHOTOS_SRC}/Gallery/${DIR}"
        if [[ "$ORGANIZATION_MODE" == "tagged" ]]; then
            DST="$HOME/DCIM/content/tagged"
        else
            DST="$HOME/DCIM/content/art--gallery/${DIR}"
        fi
        resize_images
    done
}

function process_scans() {
    LIST="album1;album2;album3;album4;babybooks;cards;certificates;graduation;misc;originals;transformers"
    echo
    echo "Processing Scans..."
    echo
    for DIR in $LIST; do
        echo "$DIR"
        SRC="${PHOTOS_SRC}/Scans/${DIR}"
        if [[ "$ORGANIZATION_MODE" == "tagged" ]]; then
            DST="$HOME/DCIM/content/tagged"
        else
            DST="$HOME/DCIM/content/scans/${DIR}"
        fi
        resize_images
    done
}

function process_photos() {
    echo "Choose processing mode:"
    echo "1. Process from specific month (YYYYMM)"
    echo "2. Process year range (YYYY-YYYY)"
    read -p "Enter your choice: " PROCESS_MODE
    
    case $PROCESS_MODE in
        1)
            # Original functionality - process from specific month
            read -p "Enter the starting month (YYYYMM): " START_MONTH
            YEAR="${START_MONTH:0:4}"
            echo
            echo "Processing Photos starting from month: $START_MONTH"
            echo
            cd "${PHOTOS_SRC}/${YEAR}"
            for DIR in $(find . -mindepth 1 -maxdepth 1 -type d -printf '%p;' | grep -E '[0-9]{6}' | sort); do
                FOLDER=$(basename $DIR)
                if [[ $FOLDER -ge $START_MONTH ]]; then
                    echo "Processing $FOLDER"
                    SRC="${PHOTOS_SRC}/${YEAR}/${FOLDER}"
                    if [[ "$ORGANIZATION_MODE" == "tagged" ]]; then
                        DST="$HOME/DCIM/content/tagged"
                    else
                        DST="$HOME/DCIM/content/photos/${YEAR}"
                    fi
                    resize_images
                fi
            done
            cd -
            ;;
        2)
            # New functionality - process year range
            read -p "Enter year range (e.g., 2003-2025): " YEAR_RANGE
            
            # Validate and parse the year range
            if [[ ! $YEAR_RANGE =~ ^[0-9]{4}-[0-9]{4}$ ]]; then
                echo "Error: Invalid year range format. Please use YYYY-YYYY format."
                return
            fi
            
            START_YEAR="${YEAR_RANGE%-*}"
            END_YEAR="${YEAR_RANGE#*-}"
            
            # Validate that start year is not greater than end year
            if [[ $START_YEAR -gt $END_YEAR ]]; then
                echo "Error: Start year cannot be greater than end year."
                return
            fi
            
            echo
            echo "Processing Photos for years: $START_YEAR to $END_YEAR"
            echo
            
            # Process each year in the range
            for ((YEAR=$START_YEAR; YEAR<=END_YEAR; YEAR++)); do
                YEAR_DIR="${PHOTOS_SRC}/${YEAR}"
                
                # Check if year directory exists
                if [[ ! -d "$YEAR_DIR" ]]; then
                    echo "Warning: Year directory $YEAR does not exist. Skipping."
                    continue
                fi
                
                echo "Processing year: $YEAR"
                cd "$YEAR_DIR"
                
                # Process all month directories in this year
                for DIR in $(find . -mindepth 1 -maxdepth 1 -type d -printf '%p;' | grep -E '[0-9]{6}' | sort); do
                    FOLDER=$(basename $DIR)
                    echo "  Processing $FOLDER"
                    SRC="${PHOTOS_SRC}/${YEAR}/${FOLDER}"
                    if [[ "$ORGANIZATION_MODE" == "tagged" ]]; then
                        DST="$HOME/DCIM/content/tagged"
                    else
                        DST="$HOME/DCIM/content/photos/${YEAR}"
                    fi
                    resize_images
                done
                cd -
            done
            ;;
        *)
            echo "Invalid choice. Returning to main menu."
            return
            ;;
    esac
}

function select_organization_mode() {
    echo "Choose how to organize generated images:"
    echo "1. Standard Directory"
    echo "2. Category Directory"
    read -p "Enter your choice: " ORG_CHOICE

    case $ORG_CHOICE in
        1)
            ORGANIZATION_MODE="standard"
            echo "Selected: Standard Directory"
            ;;
        2)
            ORGANIZATION_MODE="tagged"
            echo "Selected: Category Directory"
            ;;
        *)
            echo "Invalid choice. Defaulting to Standard Directory."
            ORGANIZATION_MODE="standard"
            ;;
    esac
}

function display_main_menu() {
    echo "1. Process Art"
    echo "2. Process Scans"
    echo "3. Process Photos"
    echo "4. Process All"
    echo "5. Change Organization Mode"
    read -p "Enter your choice: " CHOICE
}

# Main Menu Loop
select_organization_mode  # Allow user to choose the initial mode
while true; do
    display_main_menu
    case $CHOICE in
        1)
            process_art
            ;;
        2)
            process_scans
            ;;
        3)
            process_photos
            ;;
        4)
            process_art
            process_scans
            process_photos
            ;;
        5)
            select_organization_mode  # Change the organization mode
            ;;
        q)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
