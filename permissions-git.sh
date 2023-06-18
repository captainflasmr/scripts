#!/bin/bash

LIST=".config
DCIM/Art/Content/ArtAssets
DCIM/Art/Content/ArtRage
DCIM/Art/Content/ArtRagePenTool
DCIM/Art/Content/ArtRageTabletFriend
DCIM/Art/Content/InfinitePainter
DCIM/Art/Content/Krita
DCIM/content
DCIM/themes/Binario
DCIM/themes/Hugo-Octopress
DCIM/themes/Mainroad
DCIM/themes/archie
DCIM/themes/gohugo-theme-ananke
DCIM/themes/hugo-bootstrap-gallery
DCIM/themes/hugo-clarity
DCIM/themes/hugo-dead-simple
DCIM/themes/hugo-theme-notrack
DCIM/themes/hugo-w3-simple
DCIM/themes/hugo-xmag
bin
publish"

for item in $LIST; do
   echo $item
   cd ~/$item
   git diff -p -R --no-ext-diff --no-color \
      | grep -E "^(diff|(old|new) mode)" --color=never \
      | git apply
done
