#! /bin/bash
echo
echo "Move all photos from DCIM to Photos and PictureOrganise"
echo
echo "Tag photos through digikam"

echo
echo "Tagging"
echo "======="
SRC_TAG="$HOME/Photos/2024"

echo
echo "Ready to TAG ${SRC_TAG} ? : Press <any key> to continue"
read -e RESPONSE

echo "Doing $SRC_TAG..."
cd "$SRC_TAG"
echo "======="
echo "Images"
echo "======="
# tag_image_out.sh
# echo "======="
# echo "Videos"
# echo "======="
# tag_video_out.sh

echo
echo "Ready to Update content? : Press <any key> to continue"
read -e RESPONSE

echo
echo "Updating WebPage"
echo "================"
echo "======="
echo "Images"
echo "======="
images.sh
images_cat.sh
echo "======="
echo "Videos"
echo "======="
# videos.sh
