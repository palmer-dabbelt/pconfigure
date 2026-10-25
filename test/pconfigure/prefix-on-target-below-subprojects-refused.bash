#include "harness_start.bash"

# A PREFIX written after a BINARIES belongs to that one binary, which
# is a perfectly good thing to say on its own.  Below a subproject it
# splits the install just as a project-wide one would: the binary goes
# into /opt/top with a run-time search path of /opt/top/lib, and the
# library it links, read before the line, goes into /usr/local.  A
# binary that doesn't link anything from the subproject would be fine,
# but which libraries a binary uses is in its LINKOPTS and DEPLIBS and
# in whatever the subproject's own libraries pull in, and a split
# install is only found out by running the installed program on
# another machine -- so it is refused the same way, naming the line.
mkdir -p src sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
PREFIX       = /opt/top
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

grep -q "^\./Configfile:5 'PREFIX = /opt/top'" configure.out
grep -q "the subproject 'sub' was already read, and its library 'libsub.so' installs into '/usr/local'" configure.out
grep -q "above the first SUBPROJECTS or BOOTSTRAP line" configure.out
test ! -e Makefile

# Saying again, on the target, the prefix the subproject already has
# changes nothing and is fine.
sed -i 's@^PREFIX .*@PREFIX       = /usr/local/@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
test -f Makefile
