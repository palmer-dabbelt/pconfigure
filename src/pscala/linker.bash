set -e

shared="false"
mainclass="Main"
outfile=""
inputs=""
jarpath="/usr/lib $HOME/.local/lib"
jars="."
while [[ "$1" != "" ]]
do
    if [[ "$1" == "-shared" ]]
    then
	shared="true"
	shift
    elif [[ "$1" == "--main" ]]
    then
	mainclass="$2"
	shift
	shift
    elif [[ "$1" == "-o" ]]
    then
	outfile="$2"
	shift
	shift
    elif [[ "$1" == "-l" ]]
    then
	jar="$(find $jarpath -name "$2".jar; find $jarpath -name lib"$2".jar)"
	jars="$jar:$jars"
	shift
	shift
    elif [[ "$1" == "-L" ]]
    then
	jarpath="$jarpath $2"
	shift
	shift
    else
	inputs="$1 $inputs"
	shift
    fi
done

if [[ "$(echo $jars)" != "" ]]
then
    classpath="-classpath $jars"
fi

# Make a temporary working directory
workdir=`mktemp -d -t pscalald.XXXXXX`
trap "set +e; rm -rf $workdir; rm -f $outfile" EXIT

workjar="$workdir"/out.jar

# Extract every jar file we've been given
for zip in $(echo "$inputs")
do
    unzip -o -q "$zip" -d "$workdir"
done

# Create the new jar that contains every file from the extracted jars,
# with an extra argument that specifies which class to run
cd "$workdir"
find -iname "*.class" | xargs jar cfe "$workjar" $mainclass
cd - >& /dev/null

# Generate a self-extracting BASH archive as the output file
cat >"$outfile" <<EOF
#!/bin/bash
export TMPDIR=\`mktemp -d /tmp/selfextract.XXXXXX\`

ARCHIVE=\`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' \$0\`

tail -n+\$ARCHIVE \$0 | base64 -d | tar -xJ -C \$TMPDIR

scala $classpath "\$TMPDIR"/out.jar "\$@"
out="\$?"
rm -rf "\$TMPDIR"
wait

exit \$out

__ARCHIVE_BELOW__
EOF
tar -C "$workdir" -c out.jar | xz | base64 >> "$outfile"
chmod +x "$outfile"

# Shared libraries are actually completely different, it's easier to
# just tack this onto the end, though
if [[ "$shared" == "true" ]]
then
    rm -f "$outfile"
    cp "$workjar" "$outfile"
fi

# Clean up
rm -rf "$workdir"
trap "true" EXIT
