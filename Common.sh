#! /bin/bash
MYDATE=`date +%Y%m%d%H%M%S`

FILES=$(echo "$@" | sed -e "s/\s\//;\//g")

export IFS=";"

function pre () {
    # /home/jdyer/19760403181500--test-file__one@number-two-one.jpg
    A=$(echo "$A" | xargs) # trim spaces
    EXT=${A##*.} # jpg
    BASEDIR=${A%/*} # /home/jdyer
    FILE=${A##*/} # 19760403181500--test-file__one@number-two-one.jpg
    FILE_NO_EXT=${FILE%.*} # 19760403181500--test-file__one@number-two-one
    FILE_NO_TAG=${FILE//__*\./.} # 19760403181500--test-file.jpg
    FILE_NO_TAG_TIME=${FILE_NO_TAG##*--} # test-file.jpg
    FILE_RAW=${FILE_NO_TAG_TIME%\.*} # test-file

    if [[ -f "$A" ]]; then
        FULLDATE=$(date -r "$A" "+%Y%m%d%H%M%S")
    fi
    # DATE=$(date -r "$A" "+%Y-%m-%d")
    # YEAR=$(date -r "$A" "+%Y")
    # MONTH=$(date -r "$A" "+%m")
    tags=$(echo $A | sed -n "s/^.*__\(.*\)\..*$/\1/p")
    tags=${tags//_/ }
    tags=${tags//-/ } # one@number two one
    keyw=${tags//@/ } # one number two one
    keyw=$(echo $keyw | sed 's/ /\n/g' | sort | uniq | tr '\n' ';' | xargs) # one number two

    if [[ "$FILE" == "$A" ]]; then
	BASEDIR="$PWD"
	A="$BASEDIR/$A"
    fi

    if [[ "${BASEDIR}/${FILE_NO_TAG}" == "$A" ]]; then
	HASTAG=0
    else
	HASTAG=1
    fi

    TMP=$(mktemp)
}

function get_trunc_name () {
    length=28
    i=1
    TRUNCNAME=${FILE_NO_EXT//[ \#\(\)\:\?]/_}
    TRUNCNAME=$BASEDIR/${TRUNCNAME:0:$((length-${#i}))}.$EXT

    if [[ "$TRUNCNAME" != "$A" ]]; then
        while [[ -f $TRUNCNAME ]]; do
            echo $TRUNCNAME
            TRUNCNAME=${FILE_NO_EXT//[ \#\(\)\:\?]/_}
            TRUNCNAME=$BASEDIR/${TRUNCNAME:0:$((length-${#i}))}$((i++)).$EXT
        done
    fi
    TRUNCNAME=${TRUNCNAME/[_-].jpg/.jpg}
}

function convert_it () {
    ARGS="${@: 2:$#-2}"
    FIRST="${@: 1:1}"
    LAST="${@: -1}"

    convert "$FIRST" $ARGS "$TMP.$EXT"
    exiftool -overwrite_original_in_place -TagsFromFile "$FIRST" "$TMP.$EXT"
    touch -r "$FIRST" "$TMP.$EXT"
    trash-put "$FIRST"
    cp -f --preserve "$TMP.$EXT" "$LAST"
}

function convert_it_gan () {
    ARGS="${@: 2:$#-2}"
    FIRST="${@: 1:1}"
    LAST="${@: -1}"
    ARGS=${ARGS//;/ }

    # realesrgan-ncnn-vulkan -n realesrgan-x4plus -f jpg -i a.jpg -o tmp.jpg
    EXECSTR="realesrgan-ncnn-vulkan $ARGS -i $FIRST -o $TMP.$EXT"
    # EXECSTR="waifu2x-ncnn-vulkan $ARGS -i $FIRST -o $TMP.$EXT"
    echo $EXECSTR
    eval $EXECSTR
    exiftool -overwrite_original_in_place -TagsFromFile "$FIRST" "$TMP.$EXT"
    touch -r "$FIRST" "$TMP.$EXT"
    trash-put "$FIRST"
    cp -f --preserve "$TMP.$EXT" "$LAST"
}

function convert_it_video () {
    ARGS="${@: 2:$#-2}"
    FIRST="${@: 1:1}"
    LAST="${@: -1}"

    echo $ARGS
    echo $FIRST
    echo $LAST
    echo "$TMP.$EXT"

    ffmpeg -hide_banner -loglevel panic -stats -y -i "$FIRST" \
	   -map_metadata 0 -threads 8 $ARGS "$TMP.$EXT"
    touch -r "$FIRST" "$TMP.$EXT"
    # trash-put "$FIRST"
    cp -f --preserve "$TMP.$EXT" "$LAST"
}

function convert_it_text () {
    ARGS="${@: 2:$#-2}"
    FIRST="${@: 1:1}"
    LAST="${@: -1}"
    ARGS=${ARGS//;/ }

    # tesseract -l eng OCR.png output
    EXECSTR="tesseract $ARGS $FIRST $LAST"
    echo $EXECSTR
    eval $EXECSTR
}
