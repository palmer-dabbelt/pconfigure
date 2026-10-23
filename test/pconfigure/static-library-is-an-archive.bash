#include "harness_start.bash"

# The manual's LIBRARIES section: a name ending in ".a" builds a
# static archive, one ending in ".so" a shared library.  What comes
# out for "libone.a" has to be an archive -- something "ar" can list
# and that starts with ar's magic -- rather than a shared object that
# only happens to be named like one.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.a
SOURCES   += one.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

test "$(head -c 8 lib/libone.a)" = '!<arch>'
ar t lib/libone.a
