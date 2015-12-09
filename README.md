swatchify.sh infile outfile [width] [height] [clusteropts]
---

swatchify takes an image file and generates a swatch for it based on the
major colors. It accomplishes this using imagemagick's built in 
implementation of the c-means clustering algorithm. The intention is to
create a really simple swatch in an automated fashion as the foundation for a
more complex swatch system, in lieu of actual image swatches.

swatchify currently only seems to work correctly with indexed color modes for
some reason. RGBA color mode seems to take way longer and also produce
only greyscale results. I don't know why this is and I don't have a large
urge to look into it. Basically `file image.png` should have "8-bit colormap"
in the output, then you should be fine.

While the main output of swatchify is the swatch image obviously, it also
prints a simple report to stdout. This consists of the number of color
clusters, the percent of the image each cluster represents, and the center
values for each color. The orders should match up correctly. The purpose of 
this is essentially to look at the number of clusters and decide if you want
to increase the minpixels and make another pass. If it's more than three you
pretty much always want to increase it.

infile should be an image, preferably a transparent PNG. swatchify will
drop any pixels which have a value in the alpha channel greater than 200.

outfile should be a path to an output image. swatchify should support
output in any format supported by imagemagick, gif is recommended.

[width] is the output image width in pixels. It's optional. The default is 
100.

[height] is the output image height in pixels. It's optional. If not 
specified the height always matches the width in order to make a square
swatch.

[clusteropts] This is an options string which gets passed straight into
[convert -segments](http://www.imagemagick.org/script/command-line-options.php#segment).
The default is "100000x2.5" which basically means that a color cluster 
requires 100000 pixels. 2.5 is the "smoothing threshold," which is kinda
complicated and ambiguous. Basically these determine how many color groups
there will end up being. The really straightforward one is the number of
pixels, higher number means fewer groups. The smoothing threshold does things
also.

Dependencies
---
imagemagick. Specifically uses `convert -segment`. I haven't looked into which
versions of imagemagick support this functionality, but I assume it's been in
there for a while.

How does this work?
---

1. Generate a histogram, a list of all unique color values and the number of
   pixels for each color.
2. Generate a new nonsense image by dumping the histogram data into a bitmap,
   and exclude all colors with a value in the alpha channel greater than 200.
3. Run this new image through imagemagick's `-segment` routine, which is the
   c-means clustering algo. Store the generated report in `/tmp/`. minpixels
   gets passed into `-segment` here.
4. Parse the c-means report to get the cluster data. Basically this boils down
   to what the "center" color values are for each cluster and how many pixels
   exist in each cluster.
5. Generate a swatch image using the center values as the different colors and
   the number of pixels as proportional size for the bars. Currently the swatch
   is a series of vertical bars which are mirrored, just as an arbitrary
   aesthetic choice by me, this could be swapped out for all manner of possible
   layouts.

Why do it this way?
---

Generating swatches from some kind of general or main colors is actually more
complicated than it sounds. If you look at doing it with imagemagick the first
thing that comes to mind is just their simple quantization with `-colors`. The
problem with this is that it averages the colors. This means that odds are your
selected colors won't actually match ANY color in the image, and definitely not
any of the main colors in any sensical way. The c-means clustering algorithm
basically puts colors into big groups and then says "this is the most prominent
single color in the group, so it's chosen as the representative for the
group." And that's exactly what we want, turns out.
