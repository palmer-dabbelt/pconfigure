#include "harness_start.bash"

# A program is copied out of its link directory to "bin/x.tmp" and
# then renamed onto "bin/x", so that something running the old one
# keeps its own file.  "x.tmp" is a perfectly good name for a second
# program, though, and nothing used to refuse it: the first program's
# copy then landed on the second program's output and renamed it away.
# Rebuilding "x" after a source edit left "bin/x.tmp" missing, with a
# Makefile that still listed it under "all" -- make had already found
# it up to date earlier in the same run, since it comes first in the
# Configfile, and didn't look at it again.
#
# The two can't share the file, so the later line is refused, here the
# one whose temporary is the other's output.
mkdir -p src
echo 'int main(void) { return 0; }' > src/x.c
echo 'int main(void) { return 7; }' > src/scratch.c

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += x.tmp
SOURCES   += scratch.c

BINARIES  += x
SOURCES   += x.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# The refused line comes first, the way every other refusal points at
# the line it refuses; the line it collides with is named after it.
head -n1 configure.out | grep -qF "Configfile:6 'BINARIES += x'"
grep -qF "Configfile:3 'BINARIES += x.tmp'" configure.out
grep -qF "bin/x.tmp'" configure.out
grep -qF "into place through" configure.out

exit 0
