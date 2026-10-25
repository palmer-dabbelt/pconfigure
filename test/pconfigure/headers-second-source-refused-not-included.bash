#include "harness_start.bash"

# A HEADERS with the "h" language is built by BASH's targets(), so it
# is one output from one source just the same, and a second SOURCES
# was dropped just the same: never installed, and nothing said.  But
# phc is a plain copy that leaves "#include" alone, so the advice a
# BASH script gets -- include the second from the first -- would here
# install a header pointing at one that is never installed.  The
# refusal has to call it a header and say to give the second its own
# HEADERS, and doing that has to install both.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += h

HEADERS   += t.h
SOURCES   += a.h
SOURCES   += b.h
EOF2

echo 'int a;' > src/a.h
echo 'int b;' > src/b.h

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Configfile:5 'SOURCES += b.h'" pconfigure.out
grep -q "'t.h' is one header made from one source" pconfigure.out
grep -q "give b.h a HEADERS of its own" pconfigure.out
if grep -q "#include\|script" pconfigure.out
then
    exit 1
fi

# Following the advice installs both.
cat >Configfile <<'EOF2'
LANGUAGES += h

HEADERS   += t.h
SOURCES   += a.h

HEADERS   += b.h
SOURCES   += b.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -qx 'int a;' dest/usr/local/include/t.h
grep -qx 'int b;' dest/usr/local/include/b.h
