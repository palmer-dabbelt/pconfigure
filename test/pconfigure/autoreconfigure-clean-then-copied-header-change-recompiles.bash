#include "harness_start.bash"

# A HEADERSRC copies a header into the include directory, and a
# source somewhere else in the tree reads the copy through "-Iinclude"
# -- the copy is the only spelling of that header the compiler can
# find from there.  "make clean" removes the copy, since the build
# made it.  Under AUTORECONFIGURE the build after the clean then has to
# make the copy before pdeps works out what the consumer reads, or the
# fragment leaves the header out and an edit to it later is copied
# into place without the consumer being recompiled.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src/sub

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c
LANGUAGES += h

HEADERSRC += pub.h

BINARIES  += app
SOURCES   += sub/app.c
EOF

cat >src/pub.h <<'EOF'
#define VALUE 1
EOF

cat >src/sub/app.c <<'EOF'
  #include <pub.h>
  #include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

make $MAKE_ARGS clean
test ! -e include/pub.h
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
cat >src/pub.h <<'EOF'
#define VALUE 2
EOF
make $MAKE_ARGS
diff -u src/pub.h include/pub.h
test "$(./bin/app)" = "2"

exit 0
