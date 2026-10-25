#include "harness_start.bash"

# Bash's $'...' and $"..." are quoting too, and a heredoc's delimiter
# written with them is ended by the word they quote: "<<$'END'" and
# "<<$"END"" by a line saying "END".  $'...' also turns its backslash
# escapes into the characters they stand for, so "<<$'E\x4eD'" is
# ended by "END" as well.  Reading the '$' as part of the word waits
# for a line saying "$END", which no script writes, and then pbashc
# refuses the include after the heredoc and the dependency scan drops
# it.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
cat <<$'END'
one
END
#include "one.bash"
cat <<$"END"
two
END
#include "two.bash"
cat <<$'E\x4eD'
three
END
#include "three.bash"
echo tool
EOF

for n in one two three
do
    echo "echo inc-$n" >src/$n.bash
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

for n in one two three
do
    grep "^bin/tool:" Makefile | grep -q "src/$n.bash"
done

make $MAKE_ARGS

test "$(./bin/tool)" = 'one
inc-one
two
inc-two
three
inc-three
tool'
