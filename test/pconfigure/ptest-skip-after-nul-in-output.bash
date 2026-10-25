#include "harness_start.bash"

# A test that announces a skip is a skip wherever the line lands in
# its output, and the output is whatever the test printed -- which for
# a test of a compiler, an emulator or a disk image is often not text.
# One NUL byte from a tool the test ran makes grep decide the whole
# stream is binary, and then it answers on stderr that a binary file
# matched instead of printing the line.  The report sees no line, and
# a test that never ran is counted as one that passed: exactly the
# confusion the SKIP convention exists to prevent, plus a stray grep
# message in the middle of the report.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
printf 'firmware banner\0\001\002\n'
echo "SKIP: no hypervisor on this machine" >&2
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash

"$ptest" --no-check-make-check --check-dir check > report.out 2> report.err
cat report.out report.err

grep -q "^NSKIP	1$" report.out
grep -q "^NPASS	0$" report.out
grep -q "SKIP	t.bash	no hypervisor on this machine$" report.out

# Nothing about any of this is worth a message of its own.
test ! -s report.err

exit 0
