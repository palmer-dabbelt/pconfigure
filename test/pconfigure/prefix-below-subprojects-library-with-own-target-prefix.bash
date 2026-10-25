#include "harness_start.bash"

# A late PREFIX is refused when a library a subproject already built
# would be left installing somewhere else -- so what counts is where
# the library installs, and a library can be given its own PREFIX on
# its target as well as at the top of its Configfile.  Here the
# subproject's root prefix is still the /usr/local it was handed, but
# the one thing it installs was told /opt/top, so the parent moving to
# /opt/top afterwards is one consistent install and has to be left
# alone.
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
PREFIX     = /opt/top
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -f stage/opt/top/bin/main
test -f stage/opt/top/lib/libsub.so
test ! -e stage/usr/local/lib/libsub.so

# A second library left on the prefix the subproject was handed is
# still split from the parent's program, and is the one the error
# names.
cat >>sub/Configfile <<'EOF'
LIBRARIES += libother.so
SOURCES   += other.c
EOF
echo 'int other(void) { return 4; }' > sub/src/other.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^\./Configfile:2 'PREFIX = /opt/top'" configure.out
grep -q "the subproject 'sub' was already read, and its library 'libother.so' installs into '/usr/local'" configure.out
grep -q "that library was asked for at sub/Configfile:5 'LIBRARIES += libother.so'" configure.out
