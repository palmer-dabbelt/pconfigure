#include "harness_start.bash"

# A NUL byte in a file pasted in by an "#include" goes through the
# same reading as one in the script itself, and if it is refused the
# line to go and look at is in the included file rather than at the
# "#include" that brought it in.  Either the bytes come through as
# they were written or pbashc says which file and line holds them.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF2

cat >src/tool.bash <<'EOF2'
#!/bin/bash
#include "payload.bash"
EOF2

{
    printf '%s\n' 'echo payload'
    printf '# a\000b\n'
} >src/payload.bash

$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    cmp <(tail -n +2 bin/tool) src/payload.bash
else
    cat make.out
    grep -q "^src/payload\.bash:2: a NUL byte" make.out
    test ! -e bin/tool
fi
