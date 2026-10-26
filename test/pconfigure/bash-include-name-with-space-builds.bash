#include "harness_start.bash"

# pbashc pastes in "my helper.bash" without any trouble -- it reads the
# name up to the closing quote -- and the scan finds the same file.  It
# then went onto the script's rule line as written, where make splits
# it at the space and stops on 'No rule to make target src/my'.  The
# include is the script's own business, so it is pconfigure's to
# write in a form make reads back as one file.
#
# The script is written with printf, since a '#' in the first column
# of this file is a directive for this file.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += app
SOURCES     += app.bash
EOF

printf '%s\n' '#!/bin/bash' '#include "my helper.bash"' 'echo main' \
    > src/app.bash
echo 'echo helper-one' > 'src/my helper.bash'

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app | grep -qx helper-one

sleep 1
echo 'echo helper-two' > 'src/my helper.bash'
make $MAKE_ARGS
./bin/app | grep -qx helper-two
