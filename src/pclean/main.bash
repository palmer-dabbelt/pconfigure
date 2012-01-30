args=""

if [ "$1" = "-r" ]
then
    args="-maxdepth 1"
fi

find . $args -iname "*~" -print0 | while read -d $'\0' file
do
    echo "$file"
    rm "$file"
done
