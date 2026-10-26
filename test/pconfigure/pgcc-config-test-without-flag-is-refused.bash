#include "harness_start.bash"

# "pgcc-config <program> <version> [test] [flag]" only compares when
# it gets both a test and a flag.  Given a test and no flag -- a
# Configfile line whose flag came out of an empty variable, or was
# simply forgotten -- it falls through into the other mode and goes
# looking for a "fakecc-4.5.x" program, then prints "${CC}" as if it
# had been asked which compiler to use.  In a COMPILEOPTS backtick that
# is a make variable reference pasted into the compile flags.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/fakecc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 4.9.2
    exit 0
fi
exit 1
EOF
chmod +x fakebin/fakecc
export PATH="$(pwd)/fakebin:$PATH"

# The flag can go missing by being left off, or by being passed as an
# empty word from a quoted variable; a test can go missing the same
# way in front of a flag.  Each of those is refused with the usage,
# and nothing on stdout for a backtick to paste.
refused() {
    set +e
    "$gcc_config" "$@" >noflag.out 2>noflag.err
    status="$?"
    set -e
    cat noflag.out noflag.err

    test "$status" != "0"
    test ! -s noflag.out
    grep -qF "pgcc-config <program> <version> [test] [flag]" noflag.err
}

refused fakecc 4.5 gt
refused fakecc 4.5 gt ""
refused fakecc 4.5 "" -Wno-trampolines

exit 0
