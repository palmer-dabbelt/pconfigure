#include "harness_start.bash"

# When the Makefile couldn't be written the whole of the message was
# "Unable to open Makefile": not why, and not what to do.  The reason
# the system gave is the thing that tells a read-only file from a
# directory in the way from a full disk.  A directory is used here
# rather than a read-only file so that the test means the same thing
# when it is run as root.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

mkdir Makefile

status=0
$PTEST_BINARY > configure.out 2>&1 || status=$?
cat configure.out
test "$status" -ne 0
grep -q "can't write 'Makefile'" configure.out
grep -qi "is a directory" configure.out

# The directory is somebody's, and is left alone along with whatever
# is in it; the half of the write that did happen is not.
test -d Makefile
test ! -e Makefile.tmp
