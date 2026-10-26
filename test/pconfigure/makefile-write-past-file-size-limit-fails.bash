#include "harness_start.bash"

# A quota or a file-size limit stops a write part way through.  With
# SIGXFSZ ignored the write fails with EFBIG instead of killing
# pconfigure, and pconfigure carried on: the Makefile was cut off at
# the limit, in the middle of a recipe, and the run exited 0.  make
# then reads a Makefile that is missing every rule after the cut, which
# can build something and quietly skip the rest.  The run has to fail,
# and the Makefile from before has to still be the one make reads.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY
cp Makefile Makefile.before

# The Makefile for even this project is bigger than 4 KiB, while
# everything else configuring writes is far smaller.
test "$(wc -c < Makefile)" -gt 4096

status=0
( trap '' XFSZ; ulimit -f 4; exec $PTEST_BINARY ) > configure.out 2>&1 || status=$?
cat configure.out
test "$status" -ne 0
grep -q "Makefile" configure.out
grep -qi "file too large" configure.out
cmp Makefile Makefile.before
test ! -e Makefile.tmp
