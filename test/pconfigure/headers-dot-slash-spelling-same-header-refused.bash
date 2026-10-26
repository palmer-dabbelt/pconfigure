#include "harness_start.bash"

# BINARIES and LIBRARIES names are normalized, so "./main" and "main"
# are one target and two lines naming it from different sources stop
# pconfigure with "Mismatched recipe".  A HEADERS name is pasted in
# as written, though: "api/x.h" and "api/./x.h" became two make
# targets for one file, nothing compared them, and the second line's
# header was silently dropped -- a serial "make install" put the first
# in place and took the second for already done, and a parallel one
# ran both rules into the same "x.h.tmp" and failed on "mv: cannot
# stat".  Spelled identically, the same two lines are refused at
# configure time; spelled this way they have to be too.
mkdir -p src
echo 'int one;' > src/one.h
echo 'int two;' > src/two.h

cat >Configfile <<'EOF2'
LANGUAGES += h

HEADERS   += api/x.h
SOURCES   += one.h

HEADERS   += api/./x.h
SOURCES   += two.h
EOF2

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2> stderr
status="$?"
set -e
cat stderr

# Two headers asking for different contents in one file have no
# correct build, so this is a configure-time error, the same one the
# identical spelling gets.
test "$status" != 0
grep -F "Configfile:6 'HEADERS += api/./x.h'" stderr
grep -F "Mismatched recipe" stderr
