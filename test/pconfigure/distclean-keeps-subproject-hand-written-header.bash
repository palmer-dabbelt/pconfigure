#include "harness_start.bash"

# The same header-only HEADERS, one level down.  The subproject keeps
# its public header in its own include directory, where it is read
# from both by its own sources and by the parent's, and the parent's
# "make distclean" takes the subproject's output directories along
# with its own.  The subproject's include directory is not one of
# them: it holds a file the subproject's author wrote, and nothing in
# either build can make it again.
mkdir -p src sub/src sub/include

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isub/include
SOURCES     += app.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

HEADERS   += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

cat >sub/include/sub.h <<'EOF'
#define SUB_ANSWER 11
EOF

cat >sub/src/sub.c <<'EOF'
  #include <sub.h>
int sub(void) { return SUB_ANSWER; }
EOF

cat >src/app.c <<'EOF'
  #include <sub.h>
  #include <stdio.h>
int main(void) { printf("%d\n", SUB_ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "11"

make $MAKE_ARGS distclean

# The subproject's build output went with the parent's...
test ! -e sub/obj
test ! -e sub/lib

# ... and its source tree did not.
test -f sub/include/sub.h
test -f sub/src/sub.c
test -f sub/Configfile

exit 0
