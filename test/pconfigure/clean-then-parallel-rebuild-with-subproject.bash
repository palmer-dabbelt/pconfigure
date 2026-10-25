#include "harness_start.bash"

# "make clean" from the top takes the subproject's outputs along with
# the parent's, including the header copy the subproject makes, but
# leaves the subproject's Makefile -- the parent includes it, so
# without it the next make has nothing to read.  A parallel build
# after the clean then has to put the header copy back before the
# parent's source that reads it is compiled, and the library before
# the program that links it.
mkdir -p src sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isub/include
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += app.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERSRC += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void);' > sub/src/sub.h
echo 'int sub(void) { return 7; }' > sub/src/sub.c
cat >src/app.c <<'EOF'
  #include <sub.h>
  #include <stdio.h>
int main(void) { printf("%d\n", sub()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -j2
test "$(./bin/app)" = "7"

make $MAKE_ARGS clean
test ! -e bin/app
test ! -e sub/lib/libsub.so
test ! -e sub/include/sub.h
test -f sub/obj/Makefile.sub

make $MAKE_ARGS -j2
test "$(./bin/app)" = "7"

# And it settles.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

exit 0
