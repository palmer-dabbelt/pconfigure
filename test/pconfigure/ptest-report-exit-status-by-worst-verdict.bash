#include "harness_start.bash"

# What a report exits with is what "make check" fails on, so it is
# the part of the report a script reads first: one if anything
# failed, two if nothing failed but something errored, and zero
# otherwise -- skips included, since a skip says nothing is wrong
# with the tree.  A FAIL wins over an EROR when there are both,
# because the FAIL is the one somebody can act on.  And a directory
# that isn't there is "No tests", which is a success, while one that
# is there and empty is a run of nothing.

ptest="$(dirname "$PTEST_BINARY")/ptest"

result() {
    local dir="$1"
    local name="$2"
    local script="$3"
    mkdir -p "$dir"
    printf '#!/bin/bash\n%s\n' "$script" > "$dir.$name.sh"
    chmod +x "$dir.$name.sh"
    "$ptest" --test "$dir.$name.sh" --out "$dir/$name"
}

report() {
    local status=0
    "$ptest" --no-check-make-check --check-dir "$1" > "$1.out" || status=$?
    cat "$1.out" >&2
    echo "$status"
}

result passing a 'exit 0'
test "$(report passing)" = "0"

result skipping a 'echo "SKIP: nothing to run on"; exit 0'
result skipping b 'exit 0'
test "$(report skipping)" = "0"
grep -q "^NSKIP	1$" skipping.out

result erroring a 'exit 0'
result erroring b 'exit 3'
test "$(report erroring)" = "2"

result both a 'exit 1'
result both b 'exit 3'
test "$(report both)" = "1"
grep -q "^NFAIL	1$" both.out
grep -q "^NEROR	1$" both.out

test "$(report nowhere)" = "0"
grep -q "^No tests$" nowhere.out

mkdir empty
test "$(report empty)" = "0"
grep -q "^NRUN	0$" empty.out

# Quiet mode exits the same way it would have out loud.
status=0
"$ptest" --quiet --no-check-make-check --check-dir both > quiet.out || status=$?
cat quiet.out
test "$status" = "1"
grep -q "^NFAIL	1$" quiet.out
grep -q "^NEROR	1$" quiet.out

exit 0
