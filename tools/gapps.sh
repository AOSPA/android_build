#!/bin/bash

ROM_ZIP=$1
CACHE_IMAGE_ZIP=$2
OUT_FOLDER=$3
CACHE_SIZE=$4
MK_SH=$5

GAPPS_QUERY=pa_gapps-full-4.4

wget 'http://goo.im/json2&path=/devs/paranoidandroid/roms/gapps&query='$GAPPS_QUERY -O gapps.json
NEWESTGAPPS=$(cat gapps.json | grep -P -o -e $GAPPS_QUERY'.*?.zip' -m 1 | head -1)
NEWESTGAPPS_LINK=http://goo.im/devs/paranoidandroid/roms/gapps/$NEWESTGAPPS
rm -f gapps.json

if [ ! -n "$NEWESTGAPPS" ]; then
  echo "Cannot retrieve gapps from goo's api. Trying from html."
  wget 'http://goo.im/devs/paranoidandroid/roms/gapps/' -O gapps.html
  NEWESTGAPPS=$(cat gapps.html | grep -P -o -e $GAPPS_QUERY'.*?.zip' -m 1 | head -1)
  NEWESTGAPPS_LINK=$(cat gapps.html | grep -P -o -e 'http://goo.im/devs/paranoidandroid/roms/gapps//'$GAPPS_QUERY'.*?.zip' -m 1 | head -1)
  rm -f gapps.html
fi

if [ -n "$NEWESTGAPPS" ]; then
  if [ -f gapps/$NEWESTGAPPS ]; then
    echo "Latest gapps already downloaded (/gapps/$NEWESTGAPPS)"
  else
    echo "Latest gapps not found. Downloading from goo..."
    rm -rf gapps
    mkdir -p gapps
    cd gapps
    wget $NEWESTGAPPS_LINK
  fi
else
  NEWESTGAPPS=$(find gapps -name $GAPPS_QUERY'*' -printf "%f\n" | tail -1)
fi

if [ ! -n "$NEWESTGAPPS" ]; then
  echo "Couldn't download and/or locate the latest gapps package. Skipping cache image generation."
else
  rm -rf $OUT_FOLDER/cache/
  mkdir -p $OUT_FOLDER/cache/
  mkdir -p $OUT_FOLDER/cache/recovery/
  echo install /cache/rom.zip > $OUT_FOLDER/cache/recovery/openrecoveryscript
  echo install /cache/gapps.zip >> $OUT_FOLDER/cache/recovery/openrecoveryscript
  echo wipe data >> $OUT_FOLDER/cache/recovery/openrecoveryscript
  echo wipe cache >> $OUT_FOLDER/cache/recovery/openrecoveryscript
  echo wipe dalvik >> $OUT_FOLDER/cache/recovery/openrecoveryscript
  cp $ROM_ZIP $OUT_FOLDER/cache/rom.zip
  cp gapps/$NEWESTGAPPS $OUT_FOLDER/cache/gapps.zip
  ls $OUT_FOLDER/cache -sh
  $MK_SH -s $OUT_FOLDER/cache $OUT_FOLDER/cache.img ext4 /cache $CACHE_SIZE
  rm -rf $OUT_FOLDER/cache
  cd $OUT_FOLDER && zip $CACHE_IMAGE_ZIP cache.img
fi