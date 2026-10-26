#include "harness_start.bash"

# A second SRCPATH is warned about rather than refused, and what it
# does is written down: it's read with the first one inside it, so
# "--srcpath a --srcpath b" is the project under b/a.  Only the source
# directories were moved there, though.  The Configfiles were read
# from b alone, so the project's lines came from one tree and its
# sources were looked for in another, and make stopped on
# "No rule to make target 'b/a/src/fromb.c'".
#
# Each candidate directory gets a project of its own here, with a
# binary named after where it lives, so the one that gets built says
# which Configfile was read -- and it has to be b/a's, with b/a's
# source, for the build to work at all.
mkdir -p a b/src b/a/src
echo 'int main(void) { return 0; }' > b/src/fromb.c
echo 'int main(void) { return 0; }' > b/a/src/fromba.c
cat >b/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += fromb
SOURCES   += fromb.c
EOF2
cat >b/a/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += fromba
SOURCES   += fromba.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS --srcpath a --srcpath b >out 2>&1
cat out
make
test -x bin/fromba
test ! -e bin/fromb

# The warning is the only place this composition is spelled out at
# the time it happens, so it has to name the same directory the
# project was read from rather than leave "relative to the first"
# open to being read as a/b.
grep -q "'b/a'" out
