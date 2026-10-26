#include "harness_start.bash"

# An '=' is one of the characters make has no spelling for: a rule
# line with one in it is a target-specific variable assignment, escaped
# or not.  A script that includes "key=value.bash" therefore can't
# have that file as a prerequisite, and is refused at the SOURCES line
# for the script, naming the include, rather than handed to make as an
# assignment of a variable called "bin/app: src/key".
#
# The script is written with printf, since a '#' in the first column
# of this file is a directive for this file.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += bash

BINARIES    += app
SOURCES     += app.bash
EOF2

printf '%s\n' '#!/bin/bash' '#include "key=value.bash"' 'echo main' \
    > src/app.bash
echo 'echo helper' > 'src/key=value.bash'

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "Configfile:4" out
grep -q "'src/app.bash' includes 'src/key=value.bash', which the Makefile cannot name" out
