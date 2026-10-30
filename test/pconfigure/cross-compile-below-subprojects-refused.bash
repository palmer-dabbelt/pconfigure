#include "harness_start.bash"

# CROSS_COMPILE at the top of a Configfile reaches every subproject
# pulled in below it, the same way a PREFIX does -- and, like a PREFIX,
# not the ones pulled in above it, since those were read before the
# line was.  Taken as written this builds the subproject's library for
# this machine and the program that links it for another one, which
# comes out as a link that fails on a mismatched object at best.  It's
# refused, naming the line, rather than left to the linker to find.
#
# Nothing here gets far enough to run a compiler, so the toolchain
# named doesn't have to exist.
mkdir -p src sub/src

cat >Configfile <<'EOF'
SUBPROJECTS   += sub

CROSS_COMPILE  = faketc-

LANGUAGES     += c
BINARIES      += main
SOURCES       += main.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^\./Configfile:3 'CROSS_COMPILE = faketc-'" configure.out
grep -q "above the first SUBPROJECTS or BOOTSTRAP line" configure.out
test ! -e Makefile

# An empty CROSS_COMPILE -- the default -- is this machine's toolchain
# rather than one named ''.
grep -q "the subproject 'sub' was already read, and its library 'libsub.so' is built for this machine" configure.out

# A subproject that names the same toolchain itself was built with it
# whatever it was handed, so there's nothing to split.
{ echo 'CROSS_COMPILE = faketc-'; cat sub/Configfile; } > sub/Configfile.new && mv sub/Configfile.new sub/Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
test -f Makefile
