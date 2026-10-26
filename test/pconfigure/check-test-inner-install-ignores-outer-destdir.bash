#include "harness_start.bash"

# What a leaked command-line variable costs, end to end: a test that
# installs a fixture of its own into its $PTEST_TMPDIR and checks what
# landed there.  Run as "make check DESTDIR=...", the DESTDIR meant for
# the outer project reaches the inner make through the environment, the
# fixture is installed under that staging directory instead, and the
# test fails for a reason that has nothing to do with what it tests --
# while a plain "make check" of the same tree passes.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += installs-a-fixture.bash
EOF

echo 'echo hello' > src/t.bash

cat >test/t/installs-a-fixture.bash <<'EOF'
cd "$PTEST_TMPDIR"
printf 'install:\n\tmkdir -p $(DESTDIR)$(PREFIX)\n\ttouch $(DESTDIR)$(PREFIX)/installed\n' > Makefile
make install PREFIX="$PTEST_TMPDIR/prefix"
test -e "$PTEST_TMPDIR/prefix/installed"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check DESTDIR="$tempdir/stage"

tar -xOf check/t/installs-a-fixture.bash ptest__output || true
test "$(tar -xOf check/t/installs-a-fixture.bash ptest__return)" = "0"

# And nothing reached the outer staging directory.
test ! -e "$tempdir/stage"

exit 0
