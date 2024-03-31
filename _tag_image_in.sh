#!/bin/bash
# exiv2 -pa filename
declare -A array

FILES=$(find $PWD -iname '*.jpg' | tr '\n' ' ')

source Common.sh "$FILES"

for A in $FILES; do
   pre

   export IFS=" "
   for item in $tags; do
      top=${item%@*}
      bot=${item#*@}
      if [[ "$top" != "$bot" ]]; then
         array[$top]+=" $bot"
      else
         array[$top]+=""
      fi
   done

   tagCat+="<Categories>"

   for item in ${!array[@]}; do
      tagCat+="<Category Assigned=\"1\">$item"

      for index in ${array["$item"]}; do
         tagCat+="<Category Assigned=\"1\">$index</Category>"
      done
      tagCat+="</Category>"
   done

   tagCat+="</Categories>"

   exiftool -overwrite_original_in_place -Categories="$tagCat" "$A"

   keyw=${keyw//;/,}
   keyw=${keyw%,*}

   tags=${tags// /,}
   tags=${tags//@/\/}

   if [[ $tags != "" ]]; then
      exiftool -overwrite_original -sep "," -TagsList="$tags" -XMP-microsoft:LastKeywordXMP="$tags" "$A"

      tags=${tags//\//\|}
      exiftool -overwrite_original -sep "," -HierarchicalSubject="$tags" -XMP-mediapro:CatalogSets="$tags" "$A"

      exiftool -overwrite_original -sep "," -XPKeywords="$keyw" -Subject="$keyw" -Keywords="$keyw" -LastKeywordIPTC="$keyw" "$A"
   else
      printf "NO TAGS!! $A\n"
   fi
   tagCat=""
done
