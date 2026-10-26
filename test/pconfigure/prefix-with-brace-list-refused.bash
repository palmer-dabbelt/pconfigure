#include "harness_start.bash"

# PREFIX is pasted unquoted into every install recipe, which bash runs,
# and bash expands "/opt/{a,b}" into two paths: the install's mkdir
# made two directories and its cp failed with too many arguments, with
# nothing naming the line.  It is refused with the quotes, '$' and '&'
# a prefix can't hold either.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
cat >Configfile <<'EOT2'
PREFIX     = /opt/{a,b}
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a PREFIX with a brace list in it was accepted" >&2
    exit 1
fi
cat out
grep -qF "Configfile:1 'PREFIX = /opt/{a,b}'" out
grep -qF "error: PREFIX has a '{' in it" out
test ! -e Makefile
