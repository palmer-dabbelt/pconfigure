#include "harness_start.bash"

# pbashc compiles one file into one program, so a word in COMPILEOPTS
# that isn't a flag it knows is a second input.  It used to quietly
# replace the first, which here is a directory: that opens, reads as
# nothing, and came out as a script with a shebang and nothing else in
# it.  Now it is refused, naming both, and saying how a search
# directory is written -- because a bare directory is almost always
# an "-I" that lost its flag.
mkdir -p src inc

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += inc
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out

grep -q "two input files, 'src/tool\.bash' and 'inc'" make.out
grep -q "'-I dir' or '-Idir'" make.out

# And nothing was put in place, so the next make tries again rather
# than finding a program it takes for finished.
test ! -e bin/tool

exit 0
