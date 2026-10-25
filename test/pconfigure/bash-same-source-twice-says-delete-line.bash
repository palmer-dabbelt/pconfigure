#include "harness_start.bash"

# A BASH target takes one SOURCES and a second is refused with an
# "#include" to write instead.  The same file listed twice is a
# second SOURCES too, but the advice for that would have the file
# include itself, which is no answer: all there is to do is delete the
# repeated line, and that is what the message has to say.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
SOURCES   += ./tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
echo tool
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Configfile:5 'SOURCES += ./tool.bash'" pconfigure.out
grep -q "already the SOURCES of 'tool', from \./Configfile:4" pconfigure.out
grep -q "delete this line" pconfigure.out
if grep -q "#include" pconfigure.out
then
    exit 1
fi
