set -e

sources=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "-o" ]]
    then
	outfile="$2"
	shift
	shift
    else
	sources="$1 $sources"
	shift
    fi
done
workfile="$(basename "$infile")"

# Make a temporary working directory
workdir=`mktemp -d -t pscalac.XXXXXX`
trap "set +e; rm -rf $workdir; rm -f $outfile" EXIT

workjar="$workdir"/out.jar

# Copy the Scala file into the current working directory.  We need to
# make sure it's at the correct path, as otherwise I think it won't
# get loaded correctly.
scalac $sources -d "$workdir"
cd "$workdir"
find -iname "*.class" | xargs jar cf "$workjar"
cd - >& /dev/null

# Finally, copy the file
cp "$workjar" "$outfile"

# Clean up
rm -rf "$workdir"
trap "true" EXIT
