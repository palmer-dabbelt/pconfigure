#include "harness_start.bash"

# A PHONY is a name and what its TESTDEPS stand for, and "clean" is a
# name every generated Makefile already has a rule for.  make reads the
# two rules as one, so "PHONY += clean" made "make clean" build
# everything the PHONY named first -- and a tree that doesn't build,
# which is a tree somebody is very likely trying to clean, couldn't be
# cleaned at all.  It's refused at the line that named it, with the
# advice to pick a name of its own.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c
PHONY     += clean
TESTDEPS  += bin/t

BINARIES  += t
SOURCES   += t.c
EOF

echo 'int main(void) { return 0; }' > src/t.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += clean was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:2" configure.out
grep -qF "error: PHONY can't be called 'clean'" configure.out
grep -qF "give the PHONY a name of its own" configure.out
test ! -e Makefile
