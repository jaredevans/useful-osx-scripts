#!/bin/bash

# Will take multiple video files in many possible formats and convert into h.264 mp4 while resizing (and maintaining porportions) and removing the audio track. 
# Audio is removed to clear out noises in background.  Useful for me, since I am deaf and use sign language and have no idea if there is distracting background noise while recording.

# Useful for resizing large mp4 files created on phone or desktop without sarificing quality.
# Makes it a snap to send long video clips to your friends (especially while they are mobile) without consuming too much bandwidth.

# Example:
# Original Mac Photobooth MP4 video created:  7.3M
# After converting with script: 0.5M without noticeable loss of quality (14x smaller!)

# Note: If video is in 4:3 ratio, it will be still kept in same porportions when converted to 16:9 with black boxes on both sides. i.e. not stretched out and everyone looks like midgets.

# Just run script in same directory as your video files. Script will find all of them and convert them in one go. Original files will not be overwritten.

MAX_WIDTH=720
MAX_HEIGHT=480

date
export IFS=$'\n';
for i in $(find . -maxdepth 1 -type f \( -iname "*.mpg" -o -iname "*.vob" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mp4" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.mpeg" -o -iname "*.mkv" -o -iname "*.mov" \) | grep -v mobile);
  do

filename=`echo  ${i:2}`
ext=`echo ${filename} | awk -F. '{print "."$NF}'`
fn_noext=`basename "${filename}" $ext`
if [ $ext == ".mp4" ]; then
  ext=`echo "_mobile.mp4"`
else
  ext=`echo "_mobile.mp4"`
fi

  echo "Will convert to: ${fn_noext}${ext}";

  done
  echo "  "
  echo "  "

  for i in $(find . -maxdepth 1 -type f \( -iname "*.mpg" -o -iname "*.vob" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mp4" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.mpeg" -o -iname "*.mkv" -o -iname "*.mov" \) | grep -v mobile);
  do

filename=`echo  ${i:2}`
ext=`echo ${filename} | awk -F. '{print "."$NF}'`
fn_noext=`basename "${filename}" $ext`
if [ $ext == ".mp4" ]; then
  ext=`echo "_mobile.mp4"`
else
  ext=`echo "_mobile.mp4"`
fi

      echo "Resizing: ${i:2} ";\
nice -n 20 \
  ffmpeg -i ${i:2} -pix_fmt yuv420p -c:v libx264 -b:v 0.5M \
  -vf scale="iw*sar*min($MAX_WIDTH/(iw*sar)\,$MAX_HEIGHT/ih):ih*min($MAX_WIDTH/(iw*sar)\,$MAX_HEIGHT/ih),pad=$MAX_WIDTH:$MAX_HEIGHT:(ow-iw)/2:(oh-ih)/2,setsar=1/1" \
  -r:v 29/1 -force_fps -movflags +faststart -threads 0 -an -f mp4 -y ${fn_noext}${ext}
    date
    done
    exit 0
  done
done
date
