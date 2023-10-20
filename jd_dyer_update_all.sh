#! /bin/bash
echo
echo "Move all photos from DCIM to Photos and PictureOrganise"
echo
echo "Tag photos through digikam"

echo
echo "Ready to TAG? : Press <any key> to continue"
read -e RESPONSE

echo
echo "Tagging"
echo "======="
SRC_TAG="$HOME/Photos/2023"
echo "Doing $SRC_TAG..."
cd "$SRC_TAG"
echo "======="
echo "Images"
echo "======="
jd_tag_image_out.sh
echo "======="
echo "Videos"
echo "======="
jd_tag_video_out.sh

echo
echo "Ready to Update content? : Press <any key> to continue"
read -e RESPONSE

echo
echo "Updating WebPage"
echo "================"
echo "======="
echo "Images"
echo "======="
jd_dyer_images.sh
echo "======="
echo "Videos"
echo "======="
jd_dyer_videos.sh
