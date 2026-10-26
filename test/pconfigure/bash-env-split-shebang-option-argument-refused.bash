#include "harness_start.bash"

# "env -S" splits "bash -e -o pipefail" into four words, but the line
# pbashc writes names bash directly and can hand it only one.  Flags
# of a letter each fold into one word, "-o" can't: its argument is the
# word after it, and there is no single argument that says the same.
# Carried over as it stood it made a program bash refused to start, so
# pbashc stops instead, naming the line and saying what to write.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
#!/usr/bin/env -S bash -e -o pipefail
echo tool
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out

grep -q "src/tool\.bash:1: the options '-e -o pipefail'" make.out
grep -q "set -o pipefail" make.out

# Nothing was put in place, so the next make tries again.
test ! -e bin/tool

exit 0
