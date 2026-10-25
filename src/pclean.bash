args=""

if [ "$1" = "-r" ]
then
    args="-maxdepth 1"
fi

# find hands each name over NUL-terminated so that any byte a file name
# can hold gets through intact, newlines included.  The read on the
# other end has to keep it that way: without -r it treats a backslash
# as an escape and drops it (and drops a backslash-newline outright as
# a line continuation), so 'a\b~' would come back as 'ab~' and pclean
# would remove some other file, or fail to remove anything, while the
# backup it found stays put.  The empty IFS keeps read from trimming
# whitespace off either end of the name for the same reason.
find . $args -iname "*~" -print0 | while IFS= read -r -d '' file
do
    echo "$file"
    rm "$file"
done
