input=""
output=""

while [[ "$1" != "" ]]
do
    case "$1" in
    "-i") input="$2";;
    "-o") output="$2";;
    *) exit 1;;
    esac

    shift
    shift
done

# The copy is made beside the output and renamed over it, rather than
# written straight to it.  cp gives a new file the mode of the one it
# copies, and without -f it writes through a destination that already
# exists, so a header that is read-only where it comes from left a
# read-only copy behind that the next copy couldn't open -- every
# "make install" after the header changed failed, and so did the copy
# into the include directory, both while building and while
# configuring.  A rename doesn't care what the old file's mode was,
# and anything reading the output sees either the old header or the
# new one, never half of it.  The temporary is removed first because
# an interrupted run could have left a read-only one behind, which cp
# would refuse to write through for the same reason.
rm -f "$output.tmp" || exit 1
cp "$input" "$output.tmp" || exit 1
mv -f "$output.tmp" "$output"
