#include "harness_start.bash"

# A BASH binary is compiled from the one SOURCES under it.  Pointing
# it at a different source rewrites the rule's prerequisite, but a
# source that already existed is older than the script compiled from
# the old one, so make sees nothing out of date.  A C binary doesn't
# have this problem -- what goes into each link is hashed into a file
# the link reads -- and the binary that came out here used to be the
# old script under the new line.
mkdir -p src

cat >src/old.bash <<'EOF'
#!/bin/bash
echo old
EOF

cat >src/new.bash <<'EOF'
#!/bin/bash
echo new
EOF

cat >Configfile <<EOF
LANGUAGES += bash

BINARIES  += tool
SOURCES   += old.bash
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "old"

sleep 2
cat >Configfile <<EOF
LANGUAGES += bash

BINARIES  += tool
SOURCES   += new.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^bin/tool: src/new.bash" Makefile

make $MAKE_ARGS
test "$(./bin/tool)" = "new"

exit 0
