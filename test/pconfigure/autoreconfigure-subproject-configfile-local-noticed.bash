#include "harness_start.bash"

# A Configfile.local is somebody's private overrides, and a subproject
# can have one as much as the top can.  The reconfigure rule names
# every Configfile name a run looked for, in every project, whether or
# not it was there -- so one that appears for the first time inside a
# subproject is noticed by a plain make at the top.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src sub/src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

for f in src/top.c sub/src/sub.c sub/src/local.c
do
    echo 'int main(void) { return 0; }' > "$f"
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep -q '\$(wildcard sub/Configfile.local)' Makefile
grep -q '\$(wildcard sub/Configfiles/local)' Makefile
test ! -e sub/bin/local

sleep 1
cat >sub/Configfile.local <<'EOF'
LANGUAGES       += c
BINARIES        += local
SOURCES         += local.c
EOF

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
test -x sub/bin/local

# And once is enough.  The new file is a prerequisite like any other
# Configfile, so a reconfigure that left it newer than the Makefile would
# go on running on every make after this one.
make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi

exit 0
