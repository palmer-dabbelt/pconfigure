#include "harness_start.bash"

# A subproject's PHONY lands under the subproject's directory, and so
# does the subproject's source, so the two collide there just as they
# do at the top.  A same-named PHONY in the top project, which lands
# at "src/hello.c" rather than "sub/src/hello.c", names a different
# file and is fine.

mkdir -p sub/src src

cat >Configfile <<'EOF2'
LANGUAGES   += c
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c

PHONY     += src/hello.c
EOF2

echo 'int main(void) { return 0; }' > sub/src/hello.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "the subproject's PHONY += src/hello.c was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^sub/Configfile:6" configure.out
grep -qF "error: PHONY can't be called 'src/hello.c'" configure.out
grep -qF "sub/Configfile:4 'SOURCES += hello.c' reads it" configure.out

# Moved up to the top it is a name and nothing else.
sed -i.bak '/^PHONY/d' sub/Configfile
echo 'PHONY       += src/hello.c' >> Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
timeout 60 make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "Nothing to be done" again.out
