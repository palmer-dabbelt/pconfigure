#include "harness_start.bash"

# Under AUTORECONFIGURE the Makefile is remade from the Configfile
# whenever the Configfile is newer.  A PHONY called "Configfile" is in
# .PHONY, and make takes a phony as newer than everything, always, so
# every "make" reran pconfigure, re-executed, and reran it again
# without end.  The Configfile is a file the build is written out of,
# and a PHONY can't take its name.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c

BINARIES        += hello
SOURCES         += hello.c

PHONY           += Configfile
EOF2

echo 'int main(void) { return 0; }' > src/hello.c

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += Configfile was accepted" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:7" configure.out
grep -qF "error: PHONY can't be called 'Configfile'" configure.out
grep -qF "written out of" configure.out
grep -qF "give the PHONY a name of its own" configure.out
test ! -e Makefile
