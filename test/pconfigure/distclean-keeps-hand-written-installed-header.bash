#include "harness_start.bash"

# "HEADERS += api.h" with nothing under it installs a header somebody
# wrote by hand, and it reads that header out of the include
# directory: the manual says it copies $HDRDIR/api.h into the prefix
# "and will do nothing else at any other time".  So the include
# directory is a source directory here, the same as src/ is.
#
# "make distclean" is documented as removing BINDIR, OBJDIR, LIBDIR,
# TESTEXECDIR and CHECKDIR -- the directories the build writes and
# can write again.  The header was never written by the build, and
# nothing can write it again, so a distclean that takes it has thrown
# away part of the source tree.
mkdir -p include src

cat >Configfile <<EOF
LANGUAGES += c

HEADERS   += api.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >include/api.h <<'EOF'
#define API_VERSION 3
EOF

cat >src/app.c <<'EOF'
  #include <api.h>
  #include <stdio.h>
int main(void) { printf("%d\n", API_VERSION); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "3"

# The ordinary clean leaves it alone already; this is the baseline the
# distclean below is held to.
make $MAKE_ARGS clean
test -f include/api.h

make $MAKE_ARGS distclean

# What the build made is gone...
test ! -e bin
test ! -e obj
test ! -e Makefile

# ... and what somebody wrote is still there, byte for byte.
test -f include/api.h
grep -q "define API_VERSION 3" include/api.h
test -f src/app.c

exit 0
