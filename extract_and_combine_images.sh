# Andraz (@akavalar), November 2016
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>


#!/bin/bash

#clear buffer
#clear && printf '\e[3J'

filename="${1##*/}"
path="${2}"
archive="Archive"
timestamp="$(date +%s)"

filenoext="${filename%.*}"
folder="${path}${filenoext}_${timestamp}"
folder2="./${archive}"

mkdir "${folder}"
cd "${folder}"
mkdir "${archive}"
cp "${1}" "${folder}/${filename}"

# determine number of pages in PDF file
pages=$(pdfinfo "${filename}" | grep "Pages:" | grep -o '[0-9]\+') # slightly different grepping in OSX (BSD, not GNU based)

# process each page
for i in `seq 1 1 ${pages}`; do
	echo Page: $i
	page_num=$(printf %04d ${i})

	numdir_pre=$(ls -1 | wc -l)
	
	# extract images from page i
	pdfimages "${filename}" extracted -j -f $i -l $i -q
	rm *.pbm &> /dev/null
	numdir_post=$(ls -1 | wc -l)
	
	# proceed if images present
	if [ ${numdir_pre} != ${numdir_post} ]; then

		# remove images with width == 1
		for file in extracted-*.*; do
			width=$(identify ${file} | cut -d" " -f3 | cut -d"x" -f1)
			if [ ${width} == "1" ]; then
				rm ${file}
			fi
		done;

		# proceed if images still present
		if [ $(ls extracted-*.* -1 2>/dev/null | wc -l) != "0" ]; then
			
			# rename files consistently (pad with leading zeros)
			for file in extracted-*.*; do
				ext=${file#*.}
				num=${file#extracted-}
				num=${num%.*}
				num=${num#0} #problem with octal numbers if leading 0's present (specifically, problems with 08 and 09)
				num=${num#0} #do it twice...
				num=${num#0} #and one more time..
				if [ ${num} == "" ]; then
					num="0"
				fi

				file_new=${page_num}-extracted-$(printf %05d ${num}).${ext}
				file_new_jpg=${page_num}-extracted-$(printf %05d ${num}).jpg
				mv $file $file_new; # rename
				convert -rotate "-270<" ${file_new} ${file_new} # rotate 90 degrees only if width<height
				if [ ${ext} == "ppm" ]; then
					convert ${file_new} -type truecolor ${file_new_jpg} # convert to jpg # make sure not converted to grayscale
				fi;
			done;
			rm *.ppm &> /dev/null

# remove duplicates & rename consistently # deduping here doesn't work with duplicates that are not sequentially numbered
#			new_num=1
#			for file in ${page_num}-extracted-*.*; do
#				if [ ${file%.*} != ${page_num}-extracted-00000 ]; then
#					ext=${file#*.}
#					file_new=${page_num}-extracted-$(printf %05d ${new_num}).${ext}
#					if cmp -s ${file} ${file_old}; then # if duplicate, remove
#						rm ${file}
#					else
#						mv $file $file_new # if not duplicate, rename consistently
#						file_old=${file_new}
#						new_num=$((new_num + 1))
#					fi
#				else
#					file_old=${file}
#				fi
#			done;

# remove duplicates (without consistent renaming) # deduping here works with duplicates that are not sequentially numbered
#			md5sum * | sort | awk 'BEGIN{lasthash = ""} $1 == lasthash {print $2} {lasthash = $1}' | xargs rm # linux
#			md5 -r * | sort | awk 'BEGIN{lasthash = ""} $1 == lasthash {print $2} {lasthash = $1}' | xargs rm # osx

			# vertically append files
			id=1
			files_ignore=""
			
			# repeat while unprocessed images exist
			while [ $(ls ${page_num}-extracted-*.* -1 2>/dev/null | wc -l) != "0" ]; do
				
				# process unprocessed images
				for file in ${page_num}-extracted-*.*; do
					files=${file}
					width=$(identify ${file} | cut -d" " -f3 | cut -d"x" -f1)
					
					# find files from same page and with same width
					for file2 in ${page_num}-extracted-*.*; do
						width2=$(identify ${file2} | cut -d" " -f3 | cut -d"x" -f1)
						if [ ${file} != ${file2} ] && [ ${width} == ${width2} ]; then
							files="${files} ${file2}"
						fi
					done;
					
					# for images with height == 1, append them vertically
					height=$(identify ${file} | cut -d" " -f3 | cut -d"x" -f2)
					if [ ${height} == "1" ]; then
						if [ $(echo ${files} | wc -w) == "1" ]; then # if only 1 file with height == 1, then delete it
							rm ${files}
							break
						else # several "height == 1" files
							convert -append ${files} image_${page_num}_${id}.jpg
							id=$((id + 1))
							rm ${files}
							break
						fi

					# if only one or two images with height > 1, don't process them
					elif [ $(echo ${files} | wc -w) == "2" ] || [ $(echo ${files} | wc -w) == "1" ]; then
						IFS=" "; read -ra array <<< ${files}
						for file in "${array[@]}"; do
							mv $file image_${page_num}_${id}.jpg
							id=$((id + 1))
						done;
						break

					# for 3 or more images with height > 1, append them vertically but also preserve individual images
					else
						counter=0
						
						# preserve copies
						IFS=" "; read -ra array <<< ${files}
						for file in "${array[@]}"; do
							if echo "${files_ignore}" | grep -q "${file}"; then # grep -w doesn't work in OSX, but this is fine too
								continue
							else
								cp ${file} "${folder2}/${file}" # create a copy
								files_ignore="${files_ignore} ${file}" # update the to-be-ignored array (prevents overwriting of indiv images)
							fi;
						done;
						
						for file in "${array[@]}"; do
							if [ ${counter} == 0 ]; then
								convert ${file} +repage -gravity South -crop ${width}x1+0+0 +repage bottom.jpg
								file2=${file}
								counter=$((counter + 1))
							elif [ ${counter} == 1 ]; then
								convert ${file} +repage -gravity North -crop ${width}x1+0+0 +repage top1.jpg # file2a
								counter=$((counter + 1))
							elif [ ${counter} == 2 ]; then
								convert ${file} +repage -gravity North -crop ${width}x1+0+0 +repage top2.jpg
								file2b=${file}
								
								# once you have all three files, compare them
								comparison1=$(compare -metric MSE bottom.jpg top1.jpg null: 2>&1 | cut -d"(" -f2 | cut -d")" -f1)
								comparison2=$(compare -metric MSE bottom.jpg top2.jpg null: 2>&1 | cut -d"(" -f2 | cut -d")" -f1)
								
								# check if MSEs are expressed in the "base_num"e"exp_num" form
								if echo "${comparison1}" | grep -q e; then
									 base_num1=$(echo ${comparison1} | cut -d"e" -f1)
									 exp_num1=$(echo ${comparison1} | cut -d"e" -f2)
									 comparison1=$(bc -l <<< "${base_num1}*10^${exp_num1}")
									 
								fi;
								if echo "${comparison2}" | grep -q e; then
									 base_num2=$(echo ${comparison2} | cut -d"e" -f1)
									 exp_num2=$(echo ${comparison2} | cut -d"e" -f2)
									 comparison2=$(bc -l <<< "${base_num2}*10^${exp_num2}")
								fi;

								if [ $(expr ${comparison1} '<' ${comparison2}) == 1 ]; then 	# file2a is a better fit than file2b for file
									convert -append ${files} image_${page_num}_${id}.jpg
									id=$((id + 1))										
									rm ${files} bottom.jpg top1.jpg top2.jpg
									break 2
								else											# file2b better fit than file2a, append individually
									convert -append ${file2} ${file2b} ${file2b} # this preserves alphabetical order of files and makes sure we're not eventually appending two diff pics together (because file2b is after file2a)
									rm ${file2} bottom.jpg top1.jpg top2.jpg
									break 2
								fi
							fi
						done;
					fi
				done;
			done;
			
			# consistently rename backed up files
			cd "${folder2}"
			new_num=0
			for file in ${page_num}-extracted-*.*; do
				ext=${file#*.}
				file_new=${page_num}-$(printf %05d ${new_num}).${ext}
				mv "$file" "$file_new" &> /dev/null # errors not output to stdout
				new_num=$((new_num + 1))
			done;
			cd ..
		fi
	fi
done;

# remove copy of the PDF file
rm "${filename}"
