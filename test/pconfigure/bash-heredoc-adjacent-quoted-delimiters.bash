#include "harness_start.bash"

# Two heredocs can be opened by redirections written right against
# each other, "<<'A'<<'B'", and then the second body follows the
# first.  Reading the first delimiter has to stop on the '<' that ends
# it and look at that '<' again: stepping over it loses the second
# "<<", and the second body is then read as script, so an #include
# written in it gets pasted in rather than printed.  That goes for
# every spelling of the first delimiter and for a "<<-" second.  An
# unquoted "<<A<<B" also has a word character right against the
# second "<<", which elsewhere would make it a shift, but a delimiter
# holds no arithmetic and bash reads two heredocs there.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
cat <<'A'<<'B'
a
A
#include "one.bash"
B
cat <<A<<B
a
A
#include "two.bash"
B
cat <<\A<<-'B'
a
A
	#include "three.bash"
	B
#include "helper.bash"
EOF

# None of the includes in a body exist, so pasting any of them in
# fails the build rather than going unnoticed.
echo 'echo helper' >src/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
grep "^bin/tool:" Makefile | grep -q "one.bash\|two.bash\|three.bash" && exit 1

make $MAKE_ARGS

cat >expected <<'EOF'
#include "one.bash"
#include "two.bash"
#include "three.bash"
helper
EOF
./bin/tool >output
diff -u expected output
