#include "harness_start.bash"

# Bytes above 127 are ordinary characters in a Configfile value: a
# source file named in somebody's own language, or a string define
# with an accented letter in it.  The whitespace handling looks at
# every byte to decide whether it's a space, and none of these are,
# so every one has to come through untouched.
mkdir -p src
cat >'src/café.c' <<'EOF'
#include <string.h>
int main(void) { return strcmp(GREETING, "h\xc3\xa9llo w\xc3\xb6rld"); }
EOF

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += ünïcode
COMPILEOPTS += -DGREETING=\"héllo\ wörld\"
SOURCES     += café.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "src/café.c" Makefile
make $MAKE_ARGS
./bin/ünïcode
