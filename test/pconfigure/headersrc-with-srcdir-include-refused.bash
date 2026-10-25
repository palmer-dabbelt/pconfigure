#include "harness_start.bash"

# With "SRCDIR = include" a HEADERSRC's source and its copy are the
# same path, include/x.h.  pconfigure used to write the rule anyway --
# make said "Circular include/x.h <- include/x.h dependency dropped"
# on every run -- and "make distclean", which removes the copies a
# HEADERSRC made, removed the source along with them, so the header
# was gone from the tree for good.  It is refused while configuring,
# naming the line, with the source left where it was.
mkdir -p include
echo '#define X 1' > include/x.h

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h
SRCDIR     = include

HEADERSRC += x.h
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    make $MAKE_ARGS distclean || true
    ls include || true
    exit 1
fi
cat configure.out

grep -qF "Configfile:5 'HEADERSRC += x.h'" configure.out
grep -q "onto itself" configure.out
grep -qF "write 'HEADERS += x.h' instead" configure.out
grep -q "define X 1" include/x.h
test ! -e Makefile

exit 0
