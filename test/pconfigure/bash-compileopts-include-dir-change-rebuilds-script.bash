#include "harness_start.bash"

# Which file an "#include" pastes in is decided by the "-I" a script
# is compiled with.  Pointing the target at a different directory
# changes the prerequisite pconfigure lists, but both candidates are
# older than the script that was already compiled, so the new
# prerequisite is no reason for make to rebuild it -- and nothing else
# about the rule used to say the options moved, so the script kept the
# file from the directory it was pointed away from.
mkdir -p src one two

cat >src/tool.bash <<'EOF'
#!/bin/bash
#include "which.bash"
EOF

cat >one/which.bash <<'EOF'
echo one
EOF

cat >two/which.bash <<'EOF'
echo two
EOF

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Ione
SOURCES     += tool.bash
EOF

# Every input is older than the first build, so nothing that follows
# can be put down to a file that happens to be new.
sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "one"

sleep 2
cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Itwo
SOURCES     += tool.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^bin/tool:.* two/which.bash" Makefile

make $MAKE_ARGS
test "$(./bin/tool)" = "two"

exit 0
