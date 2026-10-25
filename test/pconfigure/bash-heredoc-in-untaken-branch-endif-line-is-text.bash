#include "harness_start.bash"

# A script that appends the closing "#endif" of a header guard to a
# file it is writing does it with a heredoc whose body is that one
# line.  That line is text whether or not the "#ifdef" around the
# heredoc is taken.  Read as a directive in a branch that isn't, it
# would close the "#ifdef" early and leave the real "#endif" below
# with nothing open, which pbashc aborts on -- for a script that
# builds fine with the name defined, and that configure accepted.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef WRITE_GUARD
cat >>gen.h <<'END'
#endif
END
#endif
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "tool"
