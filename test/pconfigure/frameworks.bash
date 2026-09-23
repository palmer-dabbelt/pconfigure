#include "harness_start.bash"

# FRAMEWORKS is ENTITLEMENTS's sibling: another macOS-ld64-only concept
# ("-framework Foo" has no ELF equivalent) that a Configfile can still
# write on every platform, because languages/cxx.c++ only ever turns it
# into a link argument when what's being linked is actually a Mach-O.
# Unlike ENTITLEMENTS this is exercised end to end on every platform
# this test runs on, not just Darwin: the interesting failure mode --
# "-framework Foo" leaking onto a non-Apple linker's command line -- is
# one this host can actually observe, since that flag would abort the
# build outright rather than link something wrong.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += test
FRAMEWORKS   += Foo
SOURCES      += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if [[ "$(uname -s)" == "Darwin" ]]
then
    # Where the signature is named for ENTITLEMENTS, this is where the
    # linker itself is told: on the link line building the binary.
    grep -q -- "-framework Foo" Makefile
else
    # No such framework exists to link against, so if this leaked
    # through onto the link line, the build below would fail outright
    # rather than link something silently wrong -- which is exactly
    # what makes "the build still succeeds" a real assertion here.
    if grep -q -- "-framework Foo" Makefile
    then
        echo "FRAMEWORKS leaked a '-framework' onto a non-Darwin link line" >&2
        exit 1
    fi
fi

make $MAKE_ARGS
./bin/test

##############################################################################
# FRAMEWORKS that landed somewhere nothing ever gets signed                  #
##############################################################################
# Same reasoning as ENTITLEMENTS (see strict-lint.bash): only a whole
# linked thing is ever signed, so a FRAMEWORKS that came to rest on a
# source file or a header asks for nothing.
mkdir -p lint/src
cd lint

cat >Configfile <<EOF
FRAMEWORKS   = top

LANGUAGES    += c

BINARIES     += app
FRAMEWORKS   += app
SOURCES      += app.c
FRAMEWORKS   += app

HEADERS      += foo.h
FRAMEWORKS   += app
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >src/foo.h <<EOF
int foo(void);
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > lint.out 2>&1
then
    echo "FRAMEWORKS  = top (using '=' instead of '+=') was accepted" >&2
    cat lint.out
    exit 1
fi
cat lint.out
grep -q "Command FRAMEWORKS only supports '+='" lint.out
cd ..

mkdir -p lint2/src
cd lint2

cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += app
FRAMEWORKS   += app
SOURCES      += app.c
FRAMEWORKS   += app

HEADERS      += foo.h
FRAMEWORKS   += app
EOF

cat >src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >src/foo.h <<EOF
int foo(void);
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > lint2.out 2>&1
cat lint2.out

# One of those three lines is right and two are wrong: the FRAMEWORKS
# directly under the BINARIES is the whole point of the command, the
# ones under the SOURCE and the HEADER are not.
test "$(grep -c 'warning: FRAMEWORKS written under' lint2.out)" = "2"
grep -q 'FRAMEWORKS written under a HEADER' lint2.out
grep -q 'FRAMEWORKS written under a SOURCE' lint2.out
cd ..

##############################################################################
# FRAMEWORKS reaching a linker command line as text                         #
##############################################################################
mkdir -p meta/src
cd meta

cat >Configfile <<EOF
LANGUAGES    += c

BINARIES     += main
SOURCES      += main.c
FRAMEWORKS   += Foo;touch PWNED;true
EOF
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > meta.out 2>&1
then
    echo "FRAMEWORKS with a ';' in it was accepted" >&2
    cat meta.out
    exit 1
fi
cat meta.out
grep -q "FRAMEWORKS has a ';' in it" meta.out
test ! -e Makefile
test ! -e PWNED
cd ..

exit 0
