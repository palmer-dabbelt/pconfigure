#include "harness_start.bash"

# Bash removes quoting from anywhere in a heredoc's delimiter, not
# just from the front of it: "<<E\ND", "<<'E'ND" and "<<E"N"D" all
# open a heredoc that a line saying "END" closes.  Reading the quoting
# only when it comes first takes these to be ended by "E\ND", "E'ND"
# and so on, and then the include after each heredoc is refused by
# pbashc and missed by the dependency scan.  Between double quotes a
# backslash only quotes the characters that mean something there, so
# "<<"X\Y"" keeps its backslash and is ended by "X\Y" rather than by
# "XY": an include on a line after "XY" is still body text.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
cat <<E\ND
one
END
#include "one.bash"
cat <<'E'ND
two
END
#include "two.bash"
cat <<-E"N"D
	three
	END
#include "three.bash"
cat <<"X\Y"
XY
#include "missing.bash"
X\Y
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
grep "^bin/tool:" Makefile | grep -q "missing.bash" && exit 1

make $MAKE_ARGS

# The expected output is written out as a heredoc rather than as a
# string, since an include at the start of a line in a string spanning
# several lines would be read as one when this test is compiled.
cat >expected <<'EOF'
one
inc-one
two
inc-two
three
inc-three
XY
#include "missing.bash"
tool
EOF
./bin/tool >output
diff -u expected output
