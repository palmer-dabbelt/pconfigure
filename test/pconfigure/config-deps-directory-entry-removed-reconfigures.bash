#include "harness_start.bash"

# A CONFIG_DEPS directory is watched by its modification time, which
# moves when an entry is removed just as it does when one is added.
# config-deps.bash only ever adds, so this is the other half: a test
# deleted from the enumerated directory reconfigures, the enumerating
# Configfile stops printing it, and the Makefile stops naming it.
# Keeping a check target whose source is gone would leave "make check"
# asking for a file nobody can make.

# The tests live where TESTSRC looks for them, test/<binary>/, and that
# directory is the one enumerated and watched, so "make check" at the
# end measures the Makefile against what is really on disk.
mkdir -p src test/top Configfiles

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += bash
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
CONFIG          += tests
CONFIG_DEPS     += test/top
EOF

cat >Configfiles/tests <<'EOF'
#!/bin/bash
for f in test/top/*.bash; do
    [ -e "$f" ] || continue
    echo "TESTSRC += ${f##*/}"
done
EOF
chmod +x Configfiles/tests

echo 'int main(void) { return 0; }' > src/top.c
echo 'exit 0' > test/top/first.bash
echo 'exit 0' > test/top/second.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check

# Both were enumerated, so the removal below has something to undo.
grep -q 'first.bash' Makefile
grep -q 'second.bash' Makefile

sleep 1
rm test/top/second.bash

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
grep -q 'first.bash' Makefile
if grep -q 'second.bash' Makefile
then
    echo "the removed test is still in the Makefile" >&2
    exit 1
fi

# The directory is older than the Makefile that reconfigure wrote, so
# the tree settles rather than reconfiguring on every make.
make $MAKE_ARGS > third.log 2>&1
cat third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi

# And "make check" runs what is left rather than stopping on a rule
# for the deleted source.
make $MAKE_ARGS check > check.log 2>&1 || { cat check.log; exit 1; }
cat check.log

exit 0
