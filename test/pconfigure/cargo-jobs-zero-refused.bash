#include "harness_start.bash"

# A cargo subproject's "--jobs" is checked for being digits, so that
# "--jobs lots" is refused where it was written rather than when cargo
# runs.  "--jobs 0" is all digits too, but cargo refuses it ("jobs may
# not be 0"), so a check that stops at digits takes the line without a
# word and leaves the build to fail in the middle of a make, with
# nothing pointing back at the Configfile.  "00" is the same zero
# spelled longer, and has to be refused for the same reason.
mkdir -p sub
cat >sub/Cargo.toml <<'EOF2'
[package]
name = "hello"
EOF2

for zero in 0 00
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += cargo

SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs $zero
EOF2

    rm -f Makefile
    if $PTEST_BINARY $PCONFIGURE_ARGS >jobs-$zero.out 2>&1
    then
        cat jobs-$zero.out
        exit 1
    fi
    cat jobs-$zero.out
    grep -q "Configfile:4" jobs-$zero.out
    grep -q "'--jobs $zero' isn't a number of jobs" jobs-$zero.out
    grep -q "'--jobs 4'" jobs-$zero.out
    test ! -e Makefile
done

# A number with a zero in it is still a number, and still taken.
cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs 10
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "--jobs 10" Makefile
