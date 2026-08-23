#include "harness_start.bash"

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF

cat >src/hello.c <<EOF
  #include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

# Every option that takes a value says so when it doesn't get one.
# The word after the last argument is not a word -- the standard says
# argv[argc] is a null pointer -- so reading it is how each of these
# used to die of a signal, which tells whoever typed the line nothing
# at all about what they typed.
# --ppkg-config is last on purpose: it's the one that doesn't go
# through the same parsing as the others, so it was still crashing
# after the rest had been fixed.
for option in --config --srcpath --phc --cross-compile --strict --ppkg-config
do
    status=0
    $PTEST_BINARY $option > arg.out 2>&1 || status=$?
    cat arg.out

    # It stopped, and it stopped by abort() -- 128 plus SIGABRT.  Every
    # one of these used to be 139 instead, which is 128 plus SIGSEGV:
    # a signal from reading the word after the last one, which the
    # standard says is a null pointer rather than a word.
    test "$status" -eq 134

    grep -q "Command-line option '$option' needs an argument after it" arg.out
done

# The two that print something and stop do that rather than writing a
# Makefile, whether or not there is anything here to configure.
rm -f Makefile
$PTEST_BINARY --version > version.out 2>&1
cat version.out
grep -q "^pconfigure " version.out
test ! -e Makefile

$PTEST_BINARY --help > help.out 2>&1
cat help.out
grep -q "usage: pconfigure" help.out
test ! -e Makefile

# -h is the same thing spelled shorter.
$PTEST_BINARY -h > h.out 2>&1
diff help.out h.out

# Every option the help text lists is one the parser really takes.  A
# help message that names something pconfigure rejects is worse than
# no help message at all.
for option in $(grep -oE '^  (-h, )?--[a-z-]+' help.out | grep -oE '\-\-[a-z-]+')
do
    echo "checking $option"
    $PTEST_BINARY $option > check.out 2>&1 || true

    # Either it worked, or it wanted an argument.  What it must not
    # say is that it has never heard of the option.
    if grep -q "Unable to parse command-line option" check.out
    then
        cat check.out
        exit 1
    fi
done

# --verbose leaves the recipes unsilenced, so make echoes what it
# actually runs rather than the short label pconfigure prints.
$PTEST_BINARY
grep -q "^	@cp -f " Makefile

$PTEST_BINARY --verbose
if grep -q "^	@cp -f " Makefile
then
    exit 1
fi
grep -q "^	cp -f " Makefile

# --debug says what it is building while it builds it, and still
# writes a Makefile that works.
$PTEST_BINARY --debug > debug.out 2>&1
cat debug.out
grep -q "Building Context: hello" debug.out
grep -q "target: bin/hello" debug.out

make $MAKE_ARGS
test "$(./bin/hello)" = "hello"

exit 0
