#include "harness_start.bash"

# pconfigure's scan of a script and pbashc refuse an "#if" with the
# same message, and the message quotes the line.  The scan reads a line
# with its C comments blanked out, and it used to quote that copy:
# "#if 0 // off for now" came back as "#if 0" and a run of spaces,
# which isn't the line in the file, and isn't what pbashc says about
# it either.  Both now quote the line as it was written.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
echo tool
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

cat >src/tool.bash <<'EOF2'
echo tool
#if 0 // off for now
#endif
EOF2

# pbashc's half: the project was configured before the "#if" went in,
# so make gets to it first.
if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "^src/tool\.bash:2: '#if 0 // off for now' can't be used in a script$" make.out

# And the scan's half, reading the same line.
if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
grep -q "^src/tool\.bash:2: '#if 0 // off for now' can't be used in a script$" pconfigure.out
