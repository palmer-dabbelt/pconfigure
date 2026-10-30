test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# What a PREFIX other than /usr/local changes, all in one place: where
# each kind of target is installed, what the program is told its
# prefix and libexec directory are, and the RUNPATH the installed copy
# finds its library through.  Running the installed program from /
# shows it finds its library, but not how: an install that copied the
# build-tree binary would find opt/thing/lib just as well through its
# $ORIGIN/../lib, so the RUNPATH is also read back to check that it
# names the prefix's lib/ outright.
mkdir -p src include
echo 'int f(void) { return 0; }' > src/f.c
echo 'int f(void);' > include/f.h
cat >src/main.c <<'EOF'
#include <stdio.h>
int f(void);
int main(void)
{
    puts(__PCONFIGURE__PREFIX);
    puts(__PCONFIGURE__LIBEXEC);
    return f();
}
EOF
echo 'echo hi' > src/script.bash

cat >Configfile <<EOF
PREFIX     = $tempdir/opt/thing

LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libf.so
SOURCES   += f.c

HEADERS   += f.h

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install

test -f opt/thing/lib/libf.so
test -f opt/thing/include/f.h
test -x opt/thing/bin/main
test -x opt/thing/bin/script

readelf -d opt/thing/bin/main > installed.dyn
cat installed.dyn
grep -q "R.*PATH.*$tempdir/opt/thing/lib" installed.dyn
if grep -q 'ORIGIN' installed.dyn
then
    exit 1
fi

printf '%s\n%s\n' "$tempdir/opt/thing" "$tempdir/opt/thing/libexec" > expected
(cd / && $tempdir/opt/thing/bin/main) > out
diff -u expected out
