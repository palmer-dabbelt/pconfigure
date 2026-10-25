#include "harness_start.bash"

# When every header in the include directory is a HEADERSRC copy, the
# include directory is itself something the build made, and "make
# distclean" leaving it behind empty would leave a directory nothing in
# the source tree asked for.  So once the copies are gone distclean
# takes the directory too -- but only when it is empty, which is what
# tells it apart from one that still holds a hand-written header.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += h
LANGUAGES += c

HEADERSRC += only.h

LIBRARIES += libonly.so
SOURCES   += only.c
EOF

cat >src/only.h <<'EOF'
int only(void);
EOF

cat >src/only.c <<'EOF'
  #include "only.h"
int only(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test -f include/only.h

make $MAKE_ARGS distclean

test ! -e include
test ! -e lib
test ! -e obj
test ! -e Makefile
test -f src/only.h

exit 0
