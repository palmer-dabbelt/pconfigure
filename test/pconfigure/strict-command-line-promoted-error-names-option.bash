#include "harness_start.bash"

# A warning that STRICT promotes to an error ends with the line that
# did the promoting.  That line used to be "('STRICT = v0.13' is what
# makes this an error)" whatever had asked for the strictness, so a
# "--strict v0.13" given on the command line sent the reader looking
# through Configfiles for a STRICT line no file has.
# cmdline-strict-bad-value-says-command-line-spelling.bash fixed the
# same mismatch for a bad value; this is the error a good value is
# for.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
COMPAT     = 1.0
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

if $PTEST_BINARY --strict v0.13 > out 2>&1
then
    cat out
    exit 1
fi
cat out

grep -q "^  error: COMPAT is read and then thrown away" out
grep -q "^  ('--strict v0.13' on the command line is what makes this an error)\$" out
if grep -q "STRICT = " out
then
    exit 1
fi
test ! -e Makefile

# The version is spelled the way the release is named rather than the
# way it was typed, the same as a Configfile's STRICT reads back, so
# "0.13" at the shell is still credited as "--strict v0.13".
if $PTEST_BINARY --strict 0.13 > bare.out 2>&1
then
    cat bare.out
    exit 1
fi
cat bare.out

grep -q "^  ('--strict v0.13' on the command line is what makes this an error)\$" bare.out

# A subproject inherits the flag's strictness, and with it where that
# strictness came from: the line it complains about is its own, but
# the thing that made it an error is still the flag, not some STRICT
# line in either tree.
mkdir -p inherit/src inherit/sub/src
echo 'int main(void) { return 0; }' > inherit/src/top.c
echo 'int main(void) { return 0; }' > inherit/sub/src/app.c

cat >inherit/Configfile <<'EOF2'
SUBPROJECTS += sub
LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF2

cat >inherit/sub/Configfile <<'EOF2'
LANGUAGES += c
COMPAT    = 2.0
BINARIES  += app
SOURCES   += app.c
EOF2

if (cd inherit && $PTEST_BINARY --strict v0.13) > inherit.out 2>&1
then
    cat inherit.out
    exit 1
fi
cat inherit.out

grep -q "^sub/Configfile:2 'COMPAT = 2.0'\$" inherit.out
grep -q "^  ('--strict v0.13' on the command line is what makes this an error)\$" inherit.out
