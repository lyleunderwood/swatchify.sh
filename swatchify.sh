#!/bin/bash

# swatchify infile outfile [width] [height] [clusteropts]

# swatchify takes an image file and generates a swatch for it based on the
# major colors. It accomplishes this using imagemagick's built in 
# implementation of the c-means clustering algorithm. The intention is to
# create a really simple swatch in an automated fashion as the foundation for a
# more complex swatch system, in lieu of actual image swatches.
#
# While the main output of swatchify is the swatch image obviously, it also
# prints a simple report to stdout. This consists of the number of color
# clusters, the percent of the image each cluster represents, and the center
# values for each color. The orders should match up correctly. The purpose of 
# this is essentially to look at the number of clusters and decide if you want
# to increase the minpixels and make another pass. If it's more than three you
# pretty much always want to increase it.
# 
# infile should be an image, preferably a transparent PNG. swatchify will
# drop any pixels which have a value in the alpha channel greater than 200.
# 
# outfile should be a path to an output image. swatchify should support
# output in any format supported by imagemagick, gif is recommended.
#
# [width] is the output image width in pixels. It's optional. The default is 
# 100.
#
# [height] is the output image height in pixels. It's optional. If not 
# specified the height always matches the width in order to make a square
# swatch.
# 
# [clusteropts] This is an options string which gets passed straight into
# [convert -segments](http://www.imagemagick.org/script/command-line-options.php#segment).
# The default is "100000x2.5" which basically means that a color cluster 
# requires 100000 pixels. 2.5 is the "smoothing threshold," which is kinda
# complicated and ambiguous. Basically these determine how many color groups
# there will end up being. The really straightforward one is the number of
# pixels, higher number means fewer groups. The smoothing threshold does things
# also.
#
# Depends on imagemagick, specifically uses convert -segment

if [[ -z $1 ]]
then
  >&2 echo "specify an input file as the first parameter"
  exit 1
fi

if [[ -z $2 ]]
then
  >&2 echo "specify an output file as the second parameter"
  exit 1
fi

MIN_PIXELS=100000x2.5
SWATCH_WIDTH=100.0
SWATCH_HEIGHT=100.0

if [[ -n $3 ]]
then
  SWATCH_WIDTH=$3
  SWATCH_HEIGHT=$3
fi

if [[ -n $4 ]]
then
  SWATCH_HEIGHT=$4
fi

if [[ -n $5 ]]
then
  MIN_PIXELS=$5
fi

float_scale=4
function float_eval()
{
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
        result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
        stat=$?
        if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}

SAFE_NAME=`echo $1 |sed 's/\//_/g'`

REPORT_PATH="/tmp/segments_report_${SAFE_NAME}.txt"
PARTS_PATH="/tmp/swatch_parts_${SAFE_NAME}.txt"

# all this stuff generates the color segment report
convert "$1" -define histogram:unique-colors=true -format %c histogram:info:- |
  grep ',2[0-9][0-9])' |
  sed 's/:.*#/ #/' |
    while read count color colorname; do
      convert -size 1x$count xc:$color miff:-
    done |
      convert - -gravity south -background white -append \
              miff:- |
        convert - -verbose -segment "${MIN_PIXELS}" NULL: > $REPORT_PATH

# parse the report for various values
COUNTS=(`cat $REPORT_PATH |grep 'Cluster #[0-9]* =' |sed 's/Cluster.*= //'`)
echo "Clusters: ${#COUNTS[@]}"
#echo "Counts: ${COUNTS[*]}"

TOTAL_PIXELS=0
for i in ${COUNTS[@]}; do
  let TOTAL_PIXELS+=$i
done
#echo "Total Pixels: $TOTAL_PIXELS"

COLORS=(`cat $REPORT_PATH |grep -P '[0-9.]+\s+[0-9.]+\s+[0-9.]+'`)

# calculate the percent of the total pixels each color represents
declare -a PERCENTS
for i in ${COUNTS[@]}; do
  per=$(float_eval "${i}.0 / ${TOTAL_PIXELS}.0");
  per="0$per"
  PERCENTS+=($per)
done

OLDIFS=$IFS
IFS=$'\n' SORTED_PERCENTS=($(sort -r <<< "${PERCENTS[*]}"))
IFS=$OLDIFS

declare -a COLOR_INDICES
for i in `seq 0 $(expr ${#SORTED_PERCENTS[@]} - 1)`; do
  for j in `seq 0 $(expr ${#PERCENTS[@]} - 1)`; do
    if [ "${SORTED_PERCENTS[i]}" = "${PERCENTS[j]}" ]
    then
      COLOR_INDICES+=($j)
    fi
  done
done

echo "Percents: ${SORTED_PERCENTS[*]}"

echo "Colors:"

# generate a parts report file for use in constructing the image
for i in `seq 0 $(expr ${#PERCENTS[@]} - 1)`; do
  CURRENT_INDEX=${COLOR_INDICES[$i]}
  R=${COLORS[$(expr $(($CURRENT_INDEX * 3)) + 0)]}
  G=${COLORS[$(expr $(($CURRENT_INDEX * 3)) + 1)]}
  B=${COLORS[$(expr $(($CURRENT_INDEX * 3)) + 2)]}

  PERCENT=${PERCENTS[$CURRENT_INDEX]}
  WIDTH=$(float_eval "$PERCENT * ($SWATCH_WIDTH / 2)")

  echo "$R $G $B"
  echo "$R $G $B $PERCENT $WIDTH">>$PARTS_PATH
done 

# build the actual swatch
TMP_SWATCH="/tmp/${SAFE_NAME}.swatch.png"

cat $PARTS_PATH |
  while read r g b percent width; do
    convert -size ${width}x${SWATCH_HEIGHT} xc:"rgb($r,$g,$b)" miff:-
  done |
    convert - -gravity south -background white +append \
      "$TMP_SWATCH"

convert "$TMP_SWATCH" -flop miff:- |
  convert +append "$TMP_SWATCH" - "${2}"

# clean up
rm "$PARTS_PATH" "$REPORT_PATH" "$TMP_SWATCH"
