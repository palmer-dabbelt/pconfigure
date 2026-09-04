#include "harness_start.bash"

# What a script's includes are is worked out by reading the script the
# same way pbashc reads it, and the two have to agree.  A heredoc's
# body is where they used to stop agreeing: pbashc leaves an
# "#include" in one alone, because the line belongs to whatever
# compiles the file the script is writing, and this side counted it as
# a file the script reads.
#
# What that costs is a dependency on a file the script only ever
# mentions -- so make rebuilds the script whenever that file changes,
# and the build graph says something about the tree that isn't true.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash

BINARIES  += real
SOURCES   += real.bash
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

# The heredoc here is quoted and the one inside it is not, which is
# the shape a script that generates a script actually has.  Neither
# "EOF" belongs to this file: pbashc has to hand both of them to
# tool.bash unchanged.
cat >src/tool.bash <<'OUTER'
cat >generated.c <<EOF
#include "helper.bash"
EOF
echo tool
OUTER

# The same line outside a heredoc, which is an include and has to stay
# one.  A fix that stopped reading includes in scripts altogether
# would pass every check below except this one.
cat >src/real.bash <<'OUTER'
#include "helper.bash"
echo real
OUTER

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The script that only writes the include doesn't depend on it ...
if grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
then
    exit 1
fi

# ... and the script that reads it does.
grep "^bin/real:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS

# pbashc agrees, which is the half a Makefile can't show: the line
# went into the compiled script as text, so running it writes a C file
# with the include still in it.
test "$(./bin/real)" = "helper
real"

./bin/tool
grep -q '^#include "helper.bash"$' generated.c

exit 0
