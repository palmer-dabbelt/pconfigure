#include "harness_start.bash"

# The copied-header case with the HEADERSRC written below the BINARIES
# whose source reads it.  Which line comes first says nothing about
# what the project builds, and a header the build copies is one pdeps
# has to know is coming whichever order the Configfile happened to put
# the two in: after a "make clean" the copy is gone, and a fragment
# worked out without it is one that never recompiles the program when
# the header is edited.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src/sub

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c
LANGUAGES += h

BINARIES  += app
SOURCES   += sub/app.c

HEADERSRC += pub.h
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
make $MAKE_ARGS bin/app
test "$(./bin/app)" = "1"

sleep 2
cat >src/pub.h <<'EOF'
#define VALUE 2
EOF
make $MAKE_ARGS
diff -u src/pub.h include/pub.h
test "$(./bin/app)" = "2"

exit 0
