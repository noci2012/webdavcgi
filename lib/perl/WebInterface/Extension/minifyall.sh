#!/bin/bash 

FILES='style.css script.js'


for p in $(find . -type d -name htdocs) ; do
	for file in $FILES ; do
		bn=${file%.*}
		ext=${file#*.}
		newfile=${bn}.min.${ext} 

		if [ \( ! -e "$p/$newfile" \) -o \( "$p/$file" -nt "$p/$newfile" \) ]; then
			java -jar /etc/webdavcgi/minify/yuicompressor.jar "$p/$file" > "$p/$newfile"
			test -f $"$p/$newfile" && cat "$p/$newfile"| gzip -c > "$p/${newfile}.gz"
		fi
	done

done

exit 0