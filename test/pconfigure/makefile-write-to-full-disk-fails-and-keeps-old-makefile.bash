#include "harness_start.bash"

# The Makefile was written with stdio and nothing looked at whether the
# writes, or the close that flushes them, worked: a full disk left
# whatever had made it out -- a Makefile cut off part way through a
# recipe -- and the run exited 0.  Nothing downstream can tell that
# from a configure that worked, and since the cut-off Makefile is newer
# than every Configfile, not even the next make reconfigures.
#
# So a failed write has to fail the configure, say why, and leave the
# Makefile from the last configure exactly as it was.  The Makefile is
# written beside itself and renamed into place, which is what lets a
# full disk be stood in for here by pointing that file at /dev/full.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY
cp Makefile Makefile.before

ln -s /dev/full Makefile.tmp

status=0
$PTEST_BINARY > configure.out 2>&1 || status=$?
cat configure.out
test "$status" -ne 0
grep -q "Makefile" configure.out
grep -qi "no space left on device" configure.out
cmp Makefile Makefile.before

# And what it wrote into is not left lying around for the next one.
test ! -e Makefile.tmp
test ! -L Makefile.tmp
