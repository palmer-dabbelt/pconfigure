#include "harness_start.bash"

# "<<\END" is the third way to quote a heredoc's delimiter, as old as
# the other two and still common: it means the same as "<<'END'", and
# the body ends at a line saying "END".  Reading only the quote
# characters as quoting takes the delimiter to be "\END", which no line
# ever says.  The heredoc then eats the rest of the file, so pbashc
# refuses the include after it as having been read into a heredoc's
# body, and the dependency scan drops that include -- for a script
# bash runs perfectly well.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
cat <<\END
$literal
END
#include "helper.bash"
echo tool
EOF

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The include after the heredoc is one the script reads, so editing it
# has to rebuild the script.
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"

make $MAKE_ARGS

# The body is the quoted kind, so "$literal" comes out as written, and
# the include was pasted in rather than left in the body.
test "$(./bin/tool)" = '$literal
helper
tool'
