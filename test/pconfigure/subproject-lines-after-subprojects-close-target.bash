#include "harness_start.bash"

# A SUBPROJECTS closes whatever target was open above it, so a line
# written under it that was meant for that target is in the wrong
# place.  Each of these is reported against its own line, and the
# options name the SUBPROJECTS that closed their target, rather than
# quietly attaching to whatever comes next.  The ones pconfigure can
# still make sense of -- an option that lands on the closed source, a
# SOURCES that is dropped -- are warnings and the Makefile is written
# anyway; a DEPLIBS has nothing to link into, and stops the configure.
mkdir -p src sub
echo 'int main(void) { return 0; }' > src/x.c
echo 'int y;' > src/y.c

cat >sub/Configfile <<'EOF'
LANGUAGES += c
EOF

attempt() {
    cat >Configfile <<EOF
LANGUAGES   += c
BINARIES    += x
SOURCES     += x.c
SUBPROJECTS += sub
$1
EOF
    rm -f Makefile
    $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1 || true
    cat out
}

attempt "LINKOPTS    += -lm"
grep -q "Configfile:5 'LINKOPTS += -lm'" out
grep -q "SUBPROJECTS already closed, on ./Configfile:4 'SUBPROJECTS += sub'" out
grep -q "warning: LINKOPTS" out
test -f Makefile

attempt "COMPILEOPTS += -DQ"
grep -q "Configfile:5 'COMPILEOPTS += -DQ'" out
grep -q "SUBPROJECTS already closed" out
test -f Makefile

attempt "SOURCES     += y.c"
grep -q "Configfile:5 'SOURCES += y.c'" out
grep -q "SOURCES with no target open above it is dropped" out
test -f Makefile

attempt "DEPLIBS     += m"
# A DEPLIBS has nothing to fall back onto at all, so it stops the
# configure rather than warning.
grep -q "Configfile:5 'DEPLIBS += m'" out
grep -q "error: .*DEPLIB" out
test ! -e Makefile

# The warnings become errors under STRICT, from the line that asked.
rm -f Makefile
cat >Configfile <<EOF
STRICT       = v0.13
LANGUAGES   += c
BINARIES    += x
SOURCES     += x.c
SUBPROJECTS += sub
LINKOPTS    += -lm
EOF
if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "error: LINKOPTS lands on" out
test ! -e Makefile

exit 0
