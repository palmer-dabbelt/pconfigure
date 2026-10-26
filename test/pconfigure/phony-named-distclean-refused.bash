#include "harness_start.bash"

# The same through "make distclean", the goal of last resort: a PHONY
# called "distclean" made it compile and link whatever that PHONY named
# before it threw the whole build away, and fail without throwing
# anything away when that compile failed.  Here the source is already
# broken, which is the tree distclean exists for.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c
PHONY     += distclean
TESTDEPS  += bin/t

BINARIES  += t
SOURCES   += t.c
EOF

echo 'int main(void) { return 0' > src/t.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += distclean was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:2" configure.out
grep -qF "error: PHONY can't be called 'distclean'" configure.out
test ! -e Makefile
