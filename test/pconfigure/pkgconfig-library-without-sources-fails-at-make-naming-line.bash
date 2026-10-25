#include "harness_start.bash"

# A pkgconfig LIBRARY that nothing ever gave a SOURCES is the same
# mistake as any other target with nothing in it, and pconfigure
# already has a sentence for it: a warning naming the line, which
# STRICT can turn into an error.  The pkgconfig language used to reach
# for the first of its sources to "cat" without asking whether there
# was one, so the warning was printed and pconfigure then died of a
# segmentation fault -- no Makefile, and no explanation beyond the
# warning that said this was only worth a warning.
#
# A warning means the Makefile still comes out.  There is no template
# to make a .pc out of, though, so the rule for it fails when make
# gets there and says which line it was, rather than writing out an
# empty file that a consumer's pkg-config would take at its word.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += pkgconfig
LIBRARIES += pkgconfig/x.pc
EOF

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
status="$?"
set -e
cat stderr

test "$status" == 0
grep -q "Configfile:2 'LIBRARIES += pkgconfig/x.pc'" stderr
grep -q "has nothing to build" stderr

# Nothing was built at configure time either: that copy is the one a
# consumer's ppkg-config would be answered out of.
test ! -e obj/pkgconfig/x.pc

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "Configfile:2: pkgconfig/x.pc has no SOURCES to be made from" make.out
test ! -e lib/pkgconfig/x.pc
