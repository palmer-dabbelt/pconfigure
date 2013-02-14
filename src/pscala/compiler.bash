set -e

# FIXME: Handle the "-o" flag correctly
if [[ "$1" == "" ]]
then
    echo "pscalac <INPUT.scala>"
    exit 1
fi
infile="$1"
outfile="$(basename --suffix=.scala "$infile")".jar
workfile="$(basename "$infile")"

# Make a temporary working directory
workdir=`mktemp -d -t pscalac.XXXXXX`
trap "set +e; rm -rf $workdir; rm -f $outfile" EXIT

workjar="$workdir"/out.jar

# Copy the Scala file into the current working directory.  We need to
# make sure it's at the correct path, as otherwise I think it won't
# get loaded correctly.
cp "$infile" "$workdir"/"$workfile"
cd "$workdir"
scalac "$workfile"
find -iname "*.class" | xargs jar cf "$workjar"
cd - >& /dev/null

# Finally, copy the file
cp "$workjar" "$outfile"

# Clean up
rm -rf "$workdir"
trap "true" EXIT
