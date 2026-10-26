#include "harness_start.bash"

# A source found behind a header has no Configfile line of its own, so
# its name is checked when the header is found, and refused naming the
# line that brought it in.  A file on disk can have a backtick in its
# name as easily as a backtick command's output can, and the name is
# pasted bare into the compile recipe: "src/w`true`.c" was compiled as
# "src/w.c", which isn't there, and whatever was between the backticks
# ran on every build.
mkdir -p src
echo 'int w(void);' > 'src/w`true`.h'
echo 'int w(void) { return 3; }' > 'src/w`true`.c'
cat >src/main.c <<'EOT2'
#include "w`true`.h"
int main(void) { return w(); }
EOT2
cat >Configfile <<'EOT2'
LANGUAGES   += c
BINARIES    += app
SOURCES     += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a source behind a header with a '\`' in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -qF "the source behind it, 'src/w\`true\`.c', has a '\`' in its name" out
test ! -e Makefile
