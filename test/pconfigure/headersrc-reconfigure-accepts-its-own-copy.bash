#include "harness_start.bash"

# A HEADERSRC whose copy is already in the include directory is
# refused when nothing in the build made that file, so the copy an
# earlier configure made has to be told apart from a header somebody
# wrote.  These are the ways a reconfigure finds its own copy there: a
# plain reconfigure, one after the source was edited, and one after the
# object directory -- where the record of the copy's recipe is kept --
# was deleted by hand, leaving a copy that still says what its source
# says.  None of them is a collision, and each has to go on working.
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

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h

sleep 2
echo '#define X 2' > src/x.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h

rm -rf obj
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h

make $MAKE_ARGS distclean
test ! -e include/x.h
test -f src/x.h

exit 0
