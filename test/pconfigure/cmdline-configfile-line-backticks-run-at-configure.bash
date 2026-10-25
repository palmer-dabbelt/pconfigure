#include "harness_start.bash"

# Backticks in a Configfile line are run while configuring, and what
# they print goes into the Makefile as text.  The same line given on
# the command line skipped that step: the backticks went into the
# Makefile as they were typed, so the shell running every compile ran
# the command again, and a command that fails -- which stops a
# Configfile's configure, see ppkg-config-required-package-missing-
# refused.bash -- was found out at compile time, if at all.
mkdir -p src
cat >src/hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

cat >Configfile <<'EOF'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF

$PTEST_BINARY 'LANGUAGES += c' 'COMPILEOPTS += -DVALUE=`echo 7`'
cat Makefile

# What was printed, not the command that prints it.  The command line
# itself is kept as it was typed, backticks and all, for the Makefile
# to hand back to pconfigure when it reconfigures, so that one line is
# left out of the search.
grep -q -- '-DVALUE=7' Makefile
if grep -v '^PCONFIGURE_ARGS' Makefile | grep -q 'echo 7'
then
    grep -n 'echo 7' Makefile
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/hello)" = 7

# And a command that fails stops the configure, as it does from a file.
rm -f Makefile
if $PTEST_BINARY 'LANGUAGES += c' 'COMPILEOPTS += `false`' > out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q -F "args:2 'COMPILEOPTS += "'`false`'"'" out

# The ppkg-config a backtick runs is the one --ppkg-config names, even
# when the option comes after the line on the command line: the options
# are all read before any Configfile is, so the line has to wait for
# them too if it's to mean what it would at the top of the first file.
cat >fake-ppkg-config <<'SH'
#!/bin/sh
echo -DVALUE=9
SH
chmod +x fake-ppkg-config
rm -f Makefile
$PTEST_BINARY 'LANGUAGES += c' 'COMPILEOPTS += `ppkg-config`' \
    --ppkg-config "$(pwd)/fake-ppkg-config"
grep -q -- '-DVALUE=9' Makefile
make $MAKE_ARGS
test "$(./bin/hello)" = 9
