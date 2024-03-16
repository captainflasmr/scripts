#!/bin/bash

TAGF=$PWD/TAGS

rm -f "$TAGF"

for src in `find $PWD \( -path \*/.cache -o \
         -path \*/.gnupg -o \
         -path \*/.local -o \
         -path \*/.mozilla -o \
         -path \*/.thunderbird -o \
         -path \*/.wine -o \
         -path \*/Games -o \
         -path \*/com.microsoft.Edge -o \
         -path \*/cache -o \
         -path \*/.cpan -o \
         -path \*/chromium -o \
         -path \*/elpa -o \
         -path \*/nas -o \
         -path \*/syncthing -o \
         -path \*/Image-Line -o \
         -path \*/.cargo -o \
         -path \*/.git -o \
         -path \*/.svn -o \
         -path \*/.themes -o \
         -path \*/themes -o \
         -path \*/objs -o \
         -path \*/ArtRage \) \
         -prune -o -type f -print`;
do
   case "${src}" in
      *.ad[absm]|*.[CFHMSacfhlmpsty]|*.def|*.in[cs]|*.s[as]|*.src|*.cc|\
         *.hh|*.[chy]++|*.[ch]pp|*.[chy]xx|*.pdb|*.[ch]s|*.[Cc][Oo][Bb]|\
         *.[eh]rl|*.f90|*.for|*.java|*.[cem]l|*.clisp|*.lisp|*.[Ll][Ss][Pp]|\
         [Mm]akefile*|*.pas|*.[Pp][LlMm]|*.psw|*.lm|*.pc|*.prolog|*.oak|\
         *.p[sy]|*.sch|*.scheme|*.[Ss][Cc][Mm]|*.[Ss][Mm]|*.bib|*.cl[os]|\
         *.ltx|*.sty|*.TeX|*.tex|*.texi|*.texinfo|*.txi|*.x[bp]m|*.yy|\
         *.[Ss][Qq][Ll])
         etags --append "${src}" -o "$TAGF";
         echo ${src}
         ;;
      *)
         FTYPE=`file ${src}`;
         case "${FTYPE}" in
            *script*text*)
               etags --append "${src}" -o "$TAGF";
               echo ${src}
               ;;
            *text*)
               if head -n1 "${src}" | grep '^#!' >/dev/null 2>&1;
               then
                  etags --append "${src}" -o "$TAGF";
                  echo ${src}
               fi;
               ;;
         esac;
         ;;
   esac;
done

echo
echo "Finished!"
echo
