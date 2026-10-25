#include "harness_start.bash"

# A Configfile that is there but can't be read -- checked out with the
# wrong permissions, or left behind by a "sudo" -- used to be read as
# one with no lines in it, the same answer a Configfile that doesn't
# exist gets, so pconfigure wrote an empty Makefile and "make" had
# nothing to do.  Not existing and not being readable are different
# facts: the first is a project that doesn't use that name, the second
# is one that does and whose file pconfigure couldn't open, and that
# is an error naming the file.
#
# Root reads a file with no read permission, so there is nothing to
# test there.
if test "$(id -u)" = 0
then
    echo "SKIP: root can read a file with no read permission"
    exit 0
fi

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
END
chmod 000 Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    chmod 644 Configfile
    cat out
    exit 1
fi
chmod 644 Configfile
cat out
test ! -e Makefile
grep -q "this Configfile can.t be read" out
