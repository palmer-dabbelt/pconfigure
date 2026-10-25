#include "harness_start.bash"

# "HEADERS += pub.h" with a SOURCES under it copies that source to
# include/pub.h, where everything compiled against this build reads
# it.  Switching the SOURCES to a different header rewrites the rule's
# prerequisite, but the copy is newer than a header that was already
# there, so make used to leave the old copy in place -- and the
# reconfigure, which puts a missing copy there itself, didn't replace
# one that existed.  What was in include/ was then a header the
# Configfile no longer named, and it was what got installed.
mkdir -p src

cat >src/first.h <<'EOF'
#define WHICH 1
EOF

cat >src/second.h <<'EOF'
#define WHICH 2
EOF

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERS   += pub.h
SOURCES   += first.h
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/first.h include/pub.h

sleep 2
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERS   += pub.h
SOURCES   += second.h
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^include/pub.h: src/second.h" Makefile

# The reconfigure copies a header itself, for whatever reads one before
# make has run, so the new one is already there before make is asked.
diff -u src/second.h include/pub.h

make $MAKE_ARGS
diff -u src/second.h include/pub.h

make $MAKE_ARGS DESTDIR=$(pwd)/stage install
diff -u src/second.h stage/usr/local/include/pub.h

exit 0
