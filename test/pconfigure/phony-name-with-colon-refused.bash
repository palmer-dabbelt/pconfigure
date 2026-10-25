#include "harness_start.bash"

# The same gap as a '$', with a ':': a TESTS or a BINARIES with one in
# it is refused naming the line and saying what make would do with it,
# a PHONY is pasted onto a rule line as written.  "PHONY += a:b" makes
# ".PHONY: a:b" and "a:b:", so the name is cut in two and "make a:b"
# isn't the target the Configfile asked for -- and nothing says so
# until somebody reads the Makefile.

mkdir -p src test/a:b

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash

PHONY     += a:b
TESTDEPS  += bin/tool
EOF

cat >src/tool.bash <<'EOF'
echo tool
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "Configfile:6" configure.out
grep -q "PHONY has a ':' in it" configure.out

exit 0
