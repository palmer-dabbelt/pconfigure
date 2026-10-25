#include "harness_start.bash"

# The three verdicts are drawn by the exit status alone: zero passes,
# one fails, and everything else is an EROR -- a status a test chose,
# a command the shell couldn't find, a signal from outside.  The line
# between FAIL and EROR is the one the manual spends a page on, so
# every way of landing on either side of it is pinned down here, with
# the four counts adding up to NRUN.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

run() {
    local name="$1"
    cat >"$name.sh"
    chmod +x "$name.sh"
    "$ptest" --test "$name.sh" --out "check/$name"
}

run zero <<'EOF'
#!/bin/bash
exit 0
EOF

run one <<'EOF'
#!/bin/bash
exit 1
EOF

run two <<'EOF'
#!/bin/bash
exit 2
EOF

run max <<'EOF'
#!/bin/bash
exit 255
EOF

run missing <<'EOF'
#!/bin/bash
no-such-command-anywhere-on-this-machine
EOF

run term <<'EOF'
#!/bin/bash
kill -TERM $$
EOF

run killed <<'EOF'
#!/bin/bash
kill -KILL $$
EOF

test "$(tar -xOf check/missing ptest__return)" = "127"
test "$(tar -xOf check/term ptest__return)" = "143"
test "$(tar -xOf check/killed ptest__return)" = "137"

status=0
"$ptest" --no-check-make-check --check-dir check > report.out || status=$?
cat report.out
test "$status" = "1"

grep -q "^  PASS	zero$" report.out
grep -q "^\* FAIL	one$" report.out
for name in two max missing term killed
do
    grep -q "^! EROR	$name$" report.out
done

grep -q "^NRUN	7$" report.out
grep -q "^NPASS	1$" report.out
grep -q "^NSKIP	0$" report.out
grep -q "^NFAIL	1$" report.out
grep -q "^NEROR	5$" report.out

exit 0
