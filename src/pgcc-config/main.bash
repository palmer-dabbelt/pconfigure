if [[ "$1" == "" || "$2" == "" ]]
then
    echo "pgcc-config <program> <version"
    exit 1
fi

program="$1"
version="$2"

for x in $(seq 9 -1 0)
do
    if [[ "$(which "$program"-"$version"."$x" 2>/dev/null)" != "" ]]
    then
	echo "$program"-"$version"."$x"
	exit 0
    fi
done

echo "\${CC}"
exit 1
