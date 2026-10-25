#include "harness_start.bash"

# A copy a HEADERSRC made, whose recipe record is gone with the object
# directory and whose source was edited since, can't be told apart
# from a header somebody wrote: neither has a record, and neither says
# what the source says.  It is refused along with the hand-written
# kind, since guessing wrong one way costs an rm and the other way a
# header nothing can make again.  The refusal used to say that nothing
# in this build made the file, which here is false, and so sent the
# reader looking for a header they never wrote.  It has to own up to
# the lost record and say that deleting the copy is what fixes it --
# and once the copy is deleted, the configure has to go through.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h
EOF

echo '#define X 1' > src/x.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h

sleep 1
echo '#define X 2' > src/x.h
rm -rf obj

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "a copy with no record and an edited source was accepted" >&2
    exit 1
fi
cat configure.out

grep -qF "Configfile:4 'HEADERSRC += x.h'" configure.out
grep -q "copy whose record was lost" configure.out
grep -qF "delete 'include/x.h'" configure.out
grep -q "define X 1" include/x.h

rm include/x.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h

exit 0
