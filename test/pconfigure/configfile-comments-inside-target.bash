#include "harness_start.bash"

# A comment or a blank line is nothing at all, wherever it sits: one
# between a BINARIES and its SOURCES doesn't close the binary, and one
# between two SOURCES doesn't stop the second landing on the same
# target as the first.  Comments go wherever an explanation is wanted,
# which is very often right in the middle of a target.
#
# Only a '#' that starts a line makes it a comment, whatever came
# before it in the way of whitespace; one in the middle of a value is
# part of the value, which the -DHASH below checks by reaching the
# compile line intact (the C never looks at it, since "1#2" isn't C).
mkdir -p src
cat >src/main.c <<'EOF'
int other(void);
int main(void) { return other(); }
EOF
echo 'int other(void) { return 0; }' > src/other.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
# The comment that explains what the binary is.

	# An indented comment, with a tab in front of it.
   
COMPILEOPTS += -DHASH=1#2
SOURCES     += main.c
    # A comment between two sources.

SOURCES     += other.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DHASH=1#2" Makefile
make $MAKE_ARGS

# Both sources are in the one binary: main() calls other(), so a
# binary that linked at all has both of them.
./bin/main
