#include "harness_start.bash"

# "--strict" is the same as a STRICT at the top of the first file
# that gets read, so a STRICT further down that file replaces it in
# either direction.  What an error credits has to follow the same
# rule: whichever of the two won is the one that made it an error, and
# naming the other sends the reader to change a setting that no longer
# matters.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c

# Relaxing: a project that isn't ready for what the flag asks for
# says so, and the flag's strictness is gone -- the COMPAT is a
# warning again, and a Makefile comes out.
cat >Configfile <<'EOF2'
STRICT     = v0.12
COMPAT     = 1.0
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY --strict v0.13 > relax.out 2>&1 || { cat relax.out; exit 1; }
cat relax.out

grep -q "^  warning: COMPAT is read and then thrown away" relax.out
if grep -q "^  error:" relax.out
then
    exit 1
fi
test -e Makefile
rm -f Makefile

# Tightening: the Configfile's STRICT is what promoted the warning,
# so it's the Configfile line that's named, by file and line number,
# and the flag that lost isn't mentioned at all.
cat >Configfile <<'EOF2'
LANGUAGES += c
STRICT     = v0.13
COMPAT     = 1.0
BINARIES  += hello
SOURCES   += hello.c
EOF2

if $PTEST_BINARY --strict v0.12 > tighten.out 2>&1
then
    cat tighten.out
    exit 1
fi
cat tighten.out

grep -q "^  error: COMPAT is read and then thrown away" tighten.out
grep -q "^  ('STRICT = v0.13' at \./Configfile:2 is what makes this an error)\$" tighten.out
if grep -q -- "--strict" tighten.out
then
    exit 1
fi
test ! -e Makefile
