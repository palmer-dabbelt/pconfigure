#include "harness_start.bash"

# A HEADERSRC copies its header into the include directory when
# pconfigure runs, which is what lets the scan of a source that reads
# the copy find it and make the object depend on it.  The copy used
# to be made when the HEADERSRC line's turn came, so one written below
# the BINARIES whose source reads it was made only after that source
# had been scanned: the object never depended on the header, and an
# edit to it was copied into place without the program that reads it
# being recompiled.  Which of the two lines comes first says nothing
# about what the project builds.

mkdir -p src/sub

cat >Configfile <<EOF
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

sleep 2
cat >src/pub.h <<'EOF'
#define VALUE 2
EOF
make $MAKE_ARGS
diff -u src/pub.h include/pub.h
test "$(./bin/app)" = "2"

exit 0
