#include "harness_start.bash"

# "make reconfigure" runs the pconfigure that wrote the Makefile, named
# by where it lives, rather than whatever the PATH would find first.
# reconfigure-not-in-path.bash takes every pconfigure off the PATH; this
# is the other way the bare name goes wrong, with a different one put
# ahead of it.  An installed copy older than a tree's vendored one is
# the real-world version of the decoy: it would reconfigure with the
# wrong program and say nothing about it.

mkdir -p src decoy

cat >decoy/pconfigure <<'EOF'
#!/bin/bash
echo "the decoy ran" >&2
exit 1
EOF
chmod +x decoy/pconfigure

# AUTORECONFIGURE is what gives the Makefile a rule for remaking itself
# from the Configfiles, which the second half below depends on.
cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS

# The premise: with the decoy first, the bare name finds it.  Checked
# so a PATH that somehow skipped it can't make this pass vacuously.
test "$(PATH="$(pwd)/decoy:$PATH" command -v pconfigure)" = "$(pwd)/decoy/pconfigure"

PATH="$(pwd)/decoy:$PATH" make $MAKE_ARGS reconfigure > out.log 2>&1 || { cat out.log; exit 1; }
cat out.log
grep -q "^PCONFIGURE$" out.log
if grep -q "the decoy ran" out.log
then
    exit 1
fi

# The same recipe remakes the Makefile when a Configfile is newer.  It
# has to have actually run for the decoy not running to mean anything.
sleep 1
touch Configfile
PATH="$(pwd)/decoy:$PATH" make $MAKE_ARGS > remake.log 2>&1 || { cat remake.log; exit 1; }
cat remake.log
grep -q "^PCONFIGURE$" remake.log
if grep -q "the decoy ran" remake.log
then
    exit 1
fi
test -x bin/main

exit 0
