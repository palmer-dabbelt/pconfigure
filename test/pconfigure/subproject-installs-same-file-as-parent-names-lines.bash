#include "harness_start.bash"

# Two projects in one build that install the same file -- a "main" in
# the top and another in a subproject, both headed for
# $PREFIX/bin/main -- can't both be built, and refusing is right.  The
# refusal used to be
#
#   '$(DESTDIR)/usr/local/bin/main' is built by both '' and 'sub/'
#
# and nothing else: an empty name for the top project, no Configfile,
# no line, and nothing about what to change.  The same clash inside
# one project names the line and says to give one of them a different
# name, and this one has to as well.
mkdir -p src sub/src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 1; }' > sub/src/main.c

cat >Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "two projects installing one file were accepted" >&2
    exit 1
fi
cat configure.out

# The line that made the pair heads the complaint, the way every other
# fatal error starts, and the earlier one is named as well: either of
# them is the one somebody might rename.
head -n1 configure.out | grep -q "^sub/Configfile:2 'BINARIES += main'"
grep -q "error: .*bin/main' is built by both './' and 'sub/'" configure.out
grep -q "'./' asks for it on ./Configfile:2 'BINARIES += main'" configure.out
grep -q "'sub/' asks for it on sub/Configfile:2 'BINARIES += main'" configure.out
grep -q "different name" configure.out

# Nothing about the empty name survives.
if grep -q "''" configure.out
then
    exit 1
fi
test ! -e Makefile
