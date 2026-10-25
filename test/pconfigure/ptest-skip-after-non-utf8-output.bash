#include "harness_start.bash"

# A skip is found by grepping the captured output for a line that
# starts with "SKIP:", and grep's idea of what a line of text is comes
# from the locale.  Under a UTF-8 locale a lone 0xff is not text, so a
# test that printed one -- a hexdump, a mangled file name, a Latin-1
# log -- is a test whose output grep might decide is binary, and a
# report that went that way would read the very same result tarball as
# a skip on one machine and a pass on the next.  A grep that treats
# such input as binary can also still match and print "Binary file
# (standard input) matches" in place of the line, which leaves the
# counts right and the reason garbage, so the reason has to come
# through intact as well as the verdict.  What a test printed is the
# test's business; whether it ran and why it didn't are not questions
# the locale gets a vote in, so this asks them under both.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
printf 'caf\xe9 au lait \xff\n'
echo "SKIP: cross compiler not installed"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash

# The C locale reads every byte as a character, so this half is the
# control: the result really does say it skipped.
LC_ALL=C "$ptest" --no-check-make-check --check-dir check > c.out
cat c.out
grep -q "^NSKIP	1$" c.out
grep -q "^- SKIP	t.bash	cross compiler not installed$" c.out

if ! locale -a 2>/dev/null | grep -qi '^c\.utf-\?8$'
then
    echo "SKIP: no C.UTF-8 locale on this machine" >&2
    exit 0
fi

LC_ALL=C.UTF-8 "$ptest" --no-check-make-check --check-dir check > utf8.out
cat utf8.out
grep -q "^NSKIP	1$" utf8.out
grep -q "^NPASS	0$" utf8.out
grep -q "^- SKIP	t.bash	cross compiler not installed$" utf8.out

exit 0
