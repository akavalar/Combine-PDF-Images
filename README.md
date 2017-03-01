# Combine PDF Images
Shell script for combining images extracted from PDF files

Every now and then I come across PDF files with embedded images which are cut into thin (and sometimes slightly-overlapping) slices. When you open the PDF file you don't really notice this, but it becomes an issue if you'd like to extract the image and suddenly need to deal with 3000+ image files with 1px height.

A while ago I wrote a shell script for macOS (i.e. BSD-based OS, although that's really only relevant for the way the grep syntax works). The script extracts images from PDF files and then combines them into one larger image based on their width. The script is not perfect but it works 95% of the time, which is good enough for almost-automating the end-user's work. That being said, don't expect any miracles - especially if your PDF documents have images that are wildly different from the ones I got to play with (i.e. `sample.pdf`).

The script should also be runnable on Linux machines, although you might need to fix it here and there.

## Dependencies
1. `pdfinfo` and `pdfimages` ([Poppler](http://poppler.freedesktop.org))
2. `identify`, `convert` and `compare` ([ImageMagick](http://ftp.icm.edu.pl/packages/ImageMagick/binaries/ImageMagick-x86_64-apple-darwin13.0.0.tar.gz)) 

## Usage
1. argument #1: filename of the PDF document (e.g. `sample.pdf`)
2. argument #2: path where the `filename_timestamp` directory should be created

## What does the script do?
1. creates `filename_timestamp` directory, and inside it another `Archive` directory
2. determine the number of pages in the PDF file
3. for each page:
  1. extract all images
  2. remove all images with width = 1px
  3. rename consistently, i.e. pad filenames with zeros to preserve correct order
  4. rotate 90 degrees clockwise if width<height
  5. convert .ppm images to .jpg if necessary
  6. #remove duplicates (commented out; two versions, see comments for differences)
  7. group images by widths and for each group:
	  1. stack them if their heights = 1px, then delete them
	  2. if only one or two images with height > 1px, skip and preserve them
	  3. for 3 or more images with height > 1px, append them vertically but also copy them to Archive (see below)

Sometimes the order of extracted images is messed up, so compare the bottom 1px slice of image #1 with top 1x slices of images #2 and #3:
- if the MSE of the #1 and #2 comparison is smaller, the order if fine: combine all images with such width
- if the MSE of the #1 and #3 comparison is smaller, the order is messed up: combine #1 and #3, remove #1, go back and check the MSEs again

## Why are some of the extracted images stored in Archive?
So that end-users can, if needed, stack them manually using an app like [Nori](https://delightfuldev.com/nori).
