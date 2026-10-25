#include "harness_start.bash"

# Each --cross-compile is a "CROSS_COMPILE = ..." at the top of the
# first file read, and '=' replaces, so given twice the second one is
# the one the build uses -- the way a shell alias that adds a default
# --cross-compile can be overridden by typing another one after it.
# Both are recorded for a rerun, in order, so a reconfigure lands on
# the same answer.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF

$PTEST_BINARY --cross-compile first- --cross-compile second-
cat Makefile
grep -q 'second-gcc ' Makefile
if grep -q 'first-gcc' Makefile
then
    exit 1
fi
grep -q '^PCONFIGURE_ARGS ?= --cross-compile first- --cross-compile second-$' Makefile

# And a Configfile line still has the last word over both.
(echo 'CROSS_COMPILE = third-'; cat Configfile) > Configfile.new
mv Configfile.new Configfile
$PTEST_BINARY --cross-compile first- --cross-compile second-
grep -q 'third-gcc ' Makefile
if grep -q 'second-gcc' Makefile
then
    exit 1
fi
