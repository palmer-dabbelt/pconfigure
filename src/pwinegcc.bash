# Pass through all commandline options except for -o
args=""
out=""
phase=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "-o" ]]
    then
	out="$2"
	shift
	shift
    elif [[ "$1" == "-c" ]]
    then
	phase="$1"
	shift
    else
	args="$args $1"
	shift
    fi
done

# Checks if we're doing a compile, in which case we just directly pass
# through to wine-gcc
if [[ "$phase" == "-c" ]]
then
    winegcc $args $phase -o $out
    exit $?
fi

# Find a temporary directory to target wine-gcc into
tmp=`mktemp -d /tmp/winegcc-linker.XXXXXX`

# Actually run wine-gcc, but target the temporary directory
winegcc $args -o $tmp/`basename $out`

# Generate a self-extracting BASH archive as the output file
cat >"$out" <<EOF
#!/bin/bash
export TMPDIR=\`mktemp -d /tmp/winegcc-runner.XXXXXX\`

ARCHIVE=\`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' \$0\`

tail -n+\$ARCHIVE \$0 | base64 -d | tar -xJ -C \$TMPDIR

\$TMPDIR/`basename $out` "\$@"
out="\$?"
rm -rf "\$TMPDIR"
wait

exit \$out

__ARCHIVE_BELOW__
EOF
tar -C$tmp -c . | xz | base64 >> "$out"
chmod +x "$out"

rm -rf "$tmp"
