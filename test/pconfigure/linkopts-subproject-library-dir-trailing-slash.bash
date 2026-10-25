#include "harness_start.bash"

# A "-L" naming a subproject's library directory is how a binary at the
# top finds that library, and the "-l" beside it is what becomes a
# Makefile dependency on the subproject's library -- so that asking for
# the binary alone builds the library first.  The directory is matched
# against where the library is built after tidying "./" and "//" away,
# but a trailing slash is kept, so "-Lsub/libs/" is looked up as
# "sub/libs//sub" and matches nothing.  The binary then has no
# dependency on the library and "make bin/main" links before anything
# has built it.
mkdir -p src sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -Lsub/libs/
LINKOPTS    += -lsub
SOURCES     += main.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBDIR     = libs
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^obj/bin/main/.*/local: sub/libs/libsub.so$" Makefile

make $MAKE_ARGS -j2 bin/main
./bin/main

