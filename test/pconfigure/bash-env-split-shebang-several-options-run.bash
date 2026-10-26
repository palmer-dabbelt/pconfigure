#include "harness_start.bash"

# "#!/usr/bin/env -S bash -e -u" is what "env -S" is for: the kernel
# hands env the rest of the line as one argument, and env splits it
# into "bash", "-e" and "-u".  pbashc carries the options onto its own
# "#!/bin/bash" line, but there nothing splits them -- the kernel
# passes "-e -u" to bash as a single argument, which bash refused as
# an invalid option, so the compiled program couldn't run at all.
# Flags of a letter each say the same thing run together, as "-eu".
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#!/usr/bin/env -S bash -e -u
echo "${NOT_SET_ANYWHERE}"
echo "not reached"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
head -n1 bin/tool
head -n1 bin/tool | grep -qx '#!.*/bin/bash -eu'

# "-u" makes the unset variable an error, and "-e" stops the script
# there: one message about the variable, and nothing printed.
if ./bin/tool >out 2>err
then
    exit 1
fi
cat err
test ! -s out
grep -q "NOT_SET_ANYWHERE: unbound variable" err
