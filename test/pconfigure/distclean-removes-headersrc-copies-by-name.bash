#include "harness_start.bash"

# A HEADERSRC copies its source into the include directory, which makes
# the copy build output: "make distclean" has to take it, the same as
# it takes a binary.  But the include directory is also where a
# sourceless HEADERS reads the header somebody wrote, so distclean can't
# take the directory whole.  What it can do is remove the copies by
# name, along with the directories it made to hold them, and leave the
# rest of the include directory as it found it.
mkdir -p include src/lib

cat >Configfile <<EOF
LANGUAGES += h
LANGUAGES += c

HEADERSRC += lib/copied.h
HEADERS   += api.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >include/api.h <<'EOF'
#define API_VERSION 5
EOF

cat >src/lib/copied.h <<'EOF'
#define COPIED 2
EOF

cat >src/app.c <<'EOF'
  #include <api.h>
  #include <lib/copied.h>
  #include <stdio.h>
int main(void) { printf("%d\n", API_VERSION + COPIED); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "7"
test -f include/lib/copied.h

make $MAKE_ARGS distclean

# The copy, and the directory that was only there to hold it, are gone
# with the rest of the build...
test ! -e include/lib/copied.h
test ! -e include/lib
test ! -e bin
test ! -e obj
test ! -e Makefile

# ... while the header the build never made is still there, and so is
# the source the copy was made from.
grep -q "define API_VERSION 5" include/api.h
grep -q "define COPIED 2" src/lib/copied.h

exit 0
