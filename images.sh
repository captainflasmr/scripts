#!/bin/bash

# PHOTOS_SRC="/run/media/jdyer/Backup/Photos"
PHOTOS_SRC="/run/media/jdyer/7FBD-D459/Photos"

export IFS=";"

function resize_images() {
    cd $SRC

    FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')

    source Common.sh $FILES

    mkdir -p "$DST"

    for A in $FILES; do
        pre
        # enable switching between jpg and webp
        EXTOLD=webp
        EXT=jpg
        NEWFILE="${DST}/${FILE_NO_EXT}.${EXT}"
        if [[ ! -f "${NEWFILE}" ]]; then
            printf "${NEWFILE} \n"
            # magick "$A" -auto-orient -strip -quality 30% -resize '1024x>' -resize 'x1024>' "${NEWFILE}"
            magick "$A" -auto-orient -strip -quality 40% -resize '768x>' -resize 'x768>' "${NEWFILE}"
            # apply meta data (will take longer)
            exiftool -overwrite_original -TagsFromFile "$A" "${NEWFILE}"
            touch -r "$A" "${NEWFILE}"
        fi
    done
    cd -
}

function process_art() {
    LIST="doodles;animals;got;landscapes;monsters;portraits;stilllife;buffy;kate;misc;starwars;superhero;old"
    echo
    echo "Doing Art..."
    echo
    for DIR in $LIST; do
        echo $DIR
        SRC="${PHOTOS_SRC}/Gallery/${DIR}"
        DST="$HOME/DCIM/content/art--gallery/${DIR}"
        # rm -fr $DST/*.jpg
        resize_images
    done
}

function process_scans() {
    LIST="album1;album2;album3;album4;babybooks;cards;certificates;graduation;misc;originals;transformers"
    echo
    echo "Doing Scans..."
    echo
    for DIR in $LIST; do
        echo $DIR
        SRC="${PHOTOS_SRC}/Scans/${DIR}"
        DST="$HOME/DCIM/content/scans/${DIR}"
        # rm -fr $DST/*.jpg
        resize_images
    done
}

function process_photos() {
    read -p "Enter the starting month (e.g., '202402' for February 2024): " START_MONTH
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
            DST="$HOME/DCIM/content/photos/${YEAR}"
            # rm -fr $DST/*.jpg
            resize_images
        fi
    done
    cd -
}

function display_menu() {
    echo
    echo "Select an option:"
    echo "1) Process Art"
    echo "2) Process Scans"
    echo "3) Process Photos"
    echo "4) Process All"
    echo "5) Exit"
    read -p "Enter your choice: " CHOICE
}

# Menu logic
while true; do
    display_menu
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
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
