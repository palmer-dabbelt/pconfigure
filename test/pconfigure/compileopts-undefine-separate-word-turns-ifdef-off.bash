#include "harness_start.bash"

# "-U NAME" with the name as the next word means what "-UNAME" does,
# just as "-D NAME" means "-DNAME" -- and the scan already reads the
# separate-word "-D".  Here the "-D" comes from one line and the "-U"
# from a later one, so the compiler sees EXTRA undefined and never
# reads extra.h, while the scan follows the "#ifdef" into it and links
# in a source that doesn't compile.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -D EXTRA
COMPILEOPTS += -U EXTRA
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/extra.h
echo '#error "EXTRA was undefined, so nothing reads extra.h"' >src/extra.c

cat >src/main.c <<'EOF'
#ifdef EXTRA
#include "extra.h"
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q 'src/extra' Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/app
