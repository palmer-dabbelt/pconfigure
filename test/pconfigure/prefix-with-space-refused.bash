#include "harness_start.bash"

# A space in a value that names a path is a strict.h++ warning, for
# the sake of old projects that wrote one and got away with it.
# Nothing got away with a space in PREFIX, though.  The prefix is
# pasted unquoted into every compile line as -D__PCONFIGURE__PREFIX,
# so the compiler is handed half a path and a stray file name and
# stops; and it is pasted into the install and uninstall targets,
# which make splits into two -- "make uninstall" ends up with an
# "rm -f //opt/my" of its own.  There is no project relying on a line
# that never built, so this is refused the way a metacharacter is,
# rather than warned about.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<EOF
PREFIX     = /opt/my thing

LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    echo "a PREFIX with a space in it was accepted" >&2
    exit 1
fi
cat out

grep -q "Configfile:1" out
grep -q "error:" out
grep -q "PREFIX" out
test ! -e Makefile
