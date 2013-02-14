set -e

if [[ "$1" != "-o" ]]
then
    echo "pscalac -o OUTPUT.jar INPUT1.jar .. INPUTn.jar"
    exit 1
fi

# Strip off the "-o" and the output file
shift
outfile="$1"
shift

# Default to "Main" for the class that should be run
mainclass="Main"

# Make a temporary working directory
workdir=`mktemp -d -t pscalald.XXXXXX`
trap "set +e; rm -rf $workdir; rm -f $outfile" EXIT

workjar="$workdir"/out.jar

# Extract every jar file we've been given
for zip in "$(echo "$@")"
do
    unzip -o -q "$zip" -d "$workdir"
done

# Create the new jar that contains every file from the extracted jars,
# with an extra argument that specifies which class to run
cd "$workdir"
find -iname "*.class" | xargs jar cfe "$workjar" $mainclass
cd - >& /dev/null

# Copy the output from the temporary directory to the output
cp "$workjar" "$outfile"

# Clean up
rm -rf "$workdir"
trap "true" EXIT
