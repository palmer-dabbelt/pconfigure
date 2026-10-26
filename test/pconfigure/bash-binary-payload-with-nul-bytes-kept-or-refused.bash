#include "harness_start.bash"

# A self-extracting script is a few lines of bash with an archive
# appended after an "exit", and the script reads its own tail.  The
# archive is binary, NUL bytes and all.  pbashc reads its input a line
# at a time as C strings, so everything from a NUL to the end of its
# line used to be lost without a word, and the script that came out
# read back a different payload from the one it was written with.
#
# Either answer will do here: the bytes reaching the program as they
# were written, or pbashc refusing the line and saying where it is.
# What won't do is a program that builds and carries something else.
#
# The script reads its payload by line and by length rather than as
# the end of the file, because pbashc ends a last line that has no
# newline with one, on purpose, and that newline is no part of what
# is being checked.  The "#!" line keeps every line where the source
# has it: pbashc replaces that line rather than adding one above.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

{
    printf '%s\n' '#!/bin/bash' \
        'tail -n +4 "$0" | head -c 7 | od -An -tx1 | tr -d " \n"' \
        'exit 0'
    printf 'a\000b\000c\000d'
} >src/tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    test "$(./bin/tool)" = "61006200630064"
else
    cat make.out
    grep -q "^src/tool\.bash:4: a NUL byte" make.out

    # And nothing was put in place, so the next make tries again
    # rather than finding a program it takes for finished.
    test ! -e bin/tool
fi
