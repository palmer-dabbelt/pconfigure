#include "harness_start.bash"

# A compiler that is installed but whose "-dumpversion" fails, or
# succeeds without printing anything, leaves pgcc-config with no
# version to compare just as surely as a missing one does.  Blaming
# "version " (an empty string) for not being GCC 4.x sends the reader
# after the wrong problem, so both cases have to say that no version
# came back instead.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/failing-cc <<'EOF2'
#!/bin/bash
exit 1
EOF2
cat >fakebin/silent-cc <<'EOF2'
#!/bin/bash
exit 0
EOF2
chmod +x fakebin/failing-cc fakebin/silent-cc
export PATH="$(pwd)/fakebin:$PATH"

for cc in failing-cc silent-cc
do
    set +e
    "$gcc_config" "$cc" 4.5 gt -fnew >"$cc".out 2>"$cc".err
    status="$?"
    set -e
    cat "$cc".out "$cc".err

    test "$status" != "0"
    test ! -s "$cc".out
    if grep -q -e "only GCC 4.x versions can be compared" -e "isn't a <major>.<minor> version" "$cc".err
    then
        exit 1
    fi
done

grep -q "pgcc-config: could not run failing-cc -dumpversion" failing-cc.err
grep -q "pgcc-config: silent-cc -dumpversion printed no version" silent-cc.err
