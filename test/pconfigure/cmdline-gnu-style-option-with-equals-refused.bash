#include "harness_start.bash"

# pconfigure's options take their value as the next word.  The
# "--config=debug" spelling GNU tools accept is not one of them, and it
# must not be taken for a Configfile line either -- "--config" isn't a
# command -- so it is refused, numbered and quoted, with nothing
# written.
echo 'LANGUAGES += c' > Configfile
echo 'LANGUAGES += c' > Configfile.debug

for word in --config=debug --srcpath=. --verbose=true --strict=v0.13
do
    status=0
    $PTEST_BINARY "$word" > out 2>&1 || status=$?
    cat out
    test "$status" -eq 134
    grep -qF "Unable to parse command-line option 1: '$word'" out
    test ! -e Makefile
done
