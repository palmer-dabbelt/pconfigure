#include "harness_start.bash"

# AUTODEPS = false is about what gets linked: it keeps the sources
# sitting behind a target's headers from being built and linked in
# alongside it.  A BASH target links nothing -- its sources are handed
# to pbashc and one file comes out -- so there is nothing there for it
# to aim at, and all it does is stop the includes being prerequisites.
# That is a cost with nothing on the other side of it, so it gets said
# out loud.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += bash

BINARIES  += app
AUTODEPS   = false
SOURCES   += app.bash
EOF

cat >src/lib.bash <<'EOF'
answer() { echo 1; }
EOF

cat >src/app.bash <<'EOF'
  #include "lib.bash"
answer
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > warn.out 2>&1
then
    true
else
    cat warn.out
    exit 1
fi
cat warn.out

# It points at the AUTODEPS line rather than at any of the targets
# that read it, says which language has nothing for it to do, and says
# what the line was for -- "no" on its own is no help to somebody who
# wrote it for a reason.
grep -q "Configfile:4" warn.out
grep -q "warning: 'AUTODEPS = false' takes nothing out of a bash build" warn.out
grep -q "drop the line" warn.out
grep -q "STRICT = v0.13" warn.out

# A warning and not an error: the Makefile still got written, and it
# still says what the old one said.
test -f Makefile
if grep -q "src/lib.bash" Makefile
then
    exit 1
fi

# Saying so loudly is what STRICT is for.
cat >Configfile <<EOF
STRICT     = v0.13
LANGUAGES += bash

BINARIES  += app
AUTODEPS   = false
SOURCES   += app.bash
EOF

rm -f Makefile
if $PTEST_BINARY $PCONFIGURE_ARGS > strict.out 2>&1
then
    exit 1
fi
cat strict.out
grep -q "error: 'AUTODEPS = false' takes nothing out of a bash build" strict.out
test ! -e Makefile

##############################################################################
# One line over a compiled target and the BASH tests under it                #
##############################################################################
# This is the shape the warning has to stay quiet for.  The line was
# written for the binary, where turning AUTODEPS off is the only way
# to keep the sources behind its headers out of it, and the tests
# underneath inherit it because a context is copied into whatever
# opens below it.  What that costs the tests is real, but it is a
# different complaint than this one -- this one is about a line that
# bought nothing at all.
mkdir -p $tempdir/mixed/src $tempdir/mixed/test/app
cd $tempdir/mixed

cat >Configfile <<EOF
LANGUAGES += c++
LANGUAGES += bash

BINARIES  += app
AUTODEPS   = false
SOURCES   += app.c++
TESTSRC   += t.bash
EOF

cat >src/app.c++ <<'EOF'
int main(void) { return 0; }
EOF

cat >test/app/t.bash <<'EOF'
true
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > mixed.out 2>&1
cat mixed.out
if grep -q "AUTODEPS" mixed.out
then
    exit 1
fi
test -f Makefile

exit 0
