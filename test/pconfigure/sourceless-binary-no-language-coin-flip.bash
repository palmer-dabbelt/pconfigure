#include "harness_start.bash"

# A BINARIES that nothing was ever added to is already warned about,
# by name and line, as "'main' has nothing to build".  In a project
# with two languages it was warned about a second time, as "Multiple
# valid languages ... selecting the first one: c", followed by the
# list of languages that tied.  Both of them said yes only because
# there were no sources to say no about, so the tie is between
# languages that have nothing to build either way, and the warning
# about it points at the LANGUAGES lines rather than at the target
# that's actually wrong.
mkdir -p src
echo 'int main(void) { return 0; }' > src/real.c

cat >Configfile <<'END'
LANGUAGES += c
LANGUAGES += bash
BINARIES  += main
BINARIES  += real
SOURCES   += real.c
END

# The warning that does say what's wrong is still there, and
# pconfigure still keeps going and writes a Makefile after it.
$PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
cat configure.out
grep -q "'main' has nothing to build" configure.out
test -f Makefile
if grep -q "Multiple valid languages" configure.out
then
    exit 1
fi

# And under STRICT it is still the error it was, rather than the
# missing tie having let the target through.
rm -f Makefile
sed -i '1i STRICT = v0.13' Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS >strict.out 2>&1
then
    cat strict.out
    exit 1
fi
cat strict.out
grep -q "'main' has nothing to build" strict.out

exit 0
