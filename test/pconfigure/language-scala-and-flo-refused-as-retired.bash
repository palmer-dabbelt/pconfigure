#include "harness_start.bash"

# 'scala' and 'flo' were languages of the C pconfigure, and went with
# it when it was removed without being ported.  A Configfile that
# still asks for one is an old Configfile, not a misspelled one, so
# being told to write 'c' instead -- the advice for a name pconfigure
# has never heard of -- sends whoever reads it looking for a typo that
# isn't there.  The refusal says the language is gone, still names the
# line, and points at what is left: the 'chisel' language for both,
# and for Scala the pscalac and pscalald wrappers pconfigure still
# installs.

mkdir -p src
echo 'object Top' > src/top.scala

for lang in scala flo
do
    cat >Configfile <<EOF2
BINARIES  += top
LANGUAGES += $lang
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        exit 1
    fi
    cat out
    test ! -e Makefile

    grep -q "Configfile:2" out
    grep -q "'$lang' is no longer supported" out
    grep -q "'LANGUAGES += chisel'" out
    if grep -q "'LANGUAGES += c'" out
    then
        exit 1
    fi
    if test "$lang" = scala
    then
        grep -q "pscalac and pscalald" out
    fi
done
