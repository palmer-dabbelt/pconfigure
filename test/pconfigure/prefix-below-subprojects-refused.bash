#include "harness_start.bash"

# A Configfile that opens with its SUBPROJECTS -- which is how a lot
# of them are written -- and sets its PREFIX after.  A subproject is
# read at its line and is handed whatever PREFIX was in force then, so
# taking the line would install the library into /usr/local while the
# binary that links it went into /opt/top with a run-time search path
# of /opt/top/lib: an installed program that can't find its library.
# The line is refused instead, naming it and the subproject it would
# have split from, the way AUTORECONFIGURE is refused in the same
# spot.
mkdir -p src sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub

PREFIX       = /opt/top

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += main.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^\./Configfile:3 'PREFIX = /opt/top'" configure.out
grep -q "the subproject 'sub' was already read, and its library 'libsub.so' installs into '/usr/local'" configure.out
grep -q "that library was asked for at sub/Configfile:2 'LIBRARIES += libsub.so'" configure.out
grep -q "above the first SUBPROJECTS or BOOTSTRAP line" configure.out
test ! -e Makefile

# Moved where the message says, the same project installs both halves
# into the one prefix.
cat >Configfile <<'EOF'
PREFIX       = /opt/top

SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -f stage/opt/top/bin/main
test -f stage/opt/top/lib/libsub.so
test ! -e stage/usr/local/lib/libsub.so
