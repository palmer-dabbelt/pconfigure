#include "harness_start.bash"

# pconfigure run where there is no Configfile at all -- one directory
# too deep, in src/, is the usual way to get there.  Each of the four
# default names is allowed to be missing, but with all four missing
# there is no project, and pconfigure used to write a Makefile holding
# only its built-in rules and an obj/ into the source directory, and
# exit 0.  A "--srcpath" naming a directory that isn't there is
# already refused because it would configure an empty project and exit
# successfully; running in the wrong directory is that mistake made
# without the option.  This expects the run to be refused, to name the
# files it looked for, and to write nothing.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

cd src
if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    ls -la
    exit 1
fi
cat out
test ! -e Makefile
test ! -e obj
grep -q "none of ./Configfiles/local, ./Configfile.local, ./Configfiles/main or ./Configfile exists" out
