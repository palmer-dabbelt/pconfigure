#include "harness_start.bash"

# A heredoc's body is text the script writes out, so a C file written
# that way keeps its "#if" lines, and pbashc leaves them alone.  That
# has to hold whether or not the "#ifdef" around the heredoc is taken:
# the manual says a script is refused for an "#if" or not the same way
# in a branch that isn't taken, so that whether it builds doesn't
# depend on the -D's.  Here GEN_C is never defined, and the body's
# "#if 0" must still be read as text rather than refused, just as
# pconfigure's scan of the script reads it.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef GEN_C
cat >gen.c <<'END'
#if 0
int unused;
#endif
END
#endif
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "tool"
