#!/bin/bash

# PHOTOS_SRC="/run/media/jdyer/Backup/Photos"
PHOTOS_SRC="/run/media/jdyer/7FBD-D459/Photos"

export IFS=";"

# Global variable to determine processing mode
ORGANIZATION_MODE="standard"  # Default to standard mode

function resize_images_standard() {
    cd "$SRC"
    FILES=$(find "$SRC" \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')
    source Common.sh $FILES
    mkdir -p "$DST"
    for A in $FILES; do
        pre
        EXT=jpg
        NEWFILE="${DST}/${FILE_NO_EXT}.${EXT}"
        if [[ ! -f "${NEWFILE}" ]]; then
            printf "$A -> ${NEWFILE}\n"
            magick "$A" -auto-orient -strip -quality 40% -resize '768x>' -resize 'x768>' "${NEWFILE}"
            exiftool -overwrite_original -TagsFromFile "$A" "${NEWFILE}"  # Apply metadata
            touch -r "$A" "${NEWFILE}"
        fi
    done
    cd -
}

function resize_images_tagged() {
    cd "$SRC"
    FILES=$(find "$SRC" \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')
    source Common.sh $FILES
    DST="$HOME/DCIM/content/tagged"
    mkdir -p "$DST"
    for A in $FILES; do
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
    done
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
