#include "harness_start.bash"

# An executable Configfile is run with "cd DIR && exec ./Configfile",
# and for a subproject DIR is the subproject's bare relative name.
# That is exactly the case CDPATH applies to: with CDPATH in the
# environment -- plenty of people export one from their shell's rc
# file, and "." is the usual first entry -- cd looks the name up along
# it and, having used an entry, prints the directory it went to on
# stdout.  stdout is what pconfigure reads Configfile lines from, so
# the first "line" of the subproject was its own absolute path, and
# configuring stopped on "Unable to parse".
mkdir -p lib/src
echo 'SUBPROJECTS += lib' > Configfile

cat >lib/Configfile <<'EOF'
#!/bin/sh
echo "LANGUAGES += c"
echo "BINARIES  += hello"
echo "SOURCES   += hello.c"
EOF
chmod +x lib/Configfile
echo 'int main(void) { return 0; }' > lib/src/hello.c

# Without CDPATH it configures, which is what makes the next run a
# question about the environment and nothing else.
$PTEST_BINARY
rm -f Makefile

export CDPATH=.
$PTEST_BINARY > out 2>&1 || { cat out; exit 1; }
cat out
make $MAKE_ARGS
test -x lib/bin/hello
