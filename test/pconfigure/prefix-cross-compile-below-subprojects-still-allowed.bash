#include "harness_start.bash"

# What refusing a PREFIX or CROSS_COMPILE below a SUBPROJECTS must not
# catch.  Only a line that would change what the subprojects already
# read were handed is a mistake: writing down the value they got
# anyway changes nothing, in any spelling that means the same prefix,
# and a CROSS_COMPILE under a BINARIES belongs to that one target --
# a mismatch there is a link the linker refuses, not a quiet split.
mkdir -p src sub/src

cat >Configfile <<'EOF'
PREFIX         = /opt/top
CROSS_COMPILE  =

SUBPROJECTS   += sub

PREFIX         = /opt/top/
CROSS_COMPILE  =

LANGUAGES     += c
BINARIES      += main
PREFIX         = //opt//top
CROSS_COMPILE  = faketc-
SOURCES       += main.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
test -f Makefile

# The binary was the one thing told about the other toolchain.
grep -q "faketc-" Makefile
