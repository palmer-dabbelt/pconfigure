#include "harness_start.bash"

# The manual says what happens when a CONFIG names a file that isn't
# there: a fatal error.  It's the same mistake as a misspelled command
# -- "CONFIG += libfoo_soruces" pulls in nothing at all, and every
# target that file would have declared is quietly missing from the
# build -- and it deserves the same answer, naming the line.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
CONFIG      += not-there
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a CONFIG naming a file that doesn't exist was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:5" out
grep -q "Configfiles/not-there" out
grep -q "Configfile.not-there" out
test ! -e Makefile

# An executable Configfile's lines are Configfile lines like any
# other, so a CONFIG one of them prints is held to the same rule and
# the error names the script and the line it printed.
cat >Configfiles/generated <<'EOF'
#!/bin/bash
echo "BINARIES += main"
echo "SOURCES += main.c"
echo "CONFIG += also-not-there"
EOF
chmod +x Configfiles/generated
cat >Configfile <<'EOF'
LANGUAGES   += c
CONFIG      += generated
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a CONFIG printed by an executable Configfile was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfiles/generated:3" out
grep -q "also-not-there" out
test ! -e Makefile

# A --config is documented as exactly a CONFIG, so it's refused too
# rather than being the one way left to ask for nothing by accident.
cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS --config nor-this >out 2>&1
then
    cat out
    echo "a --config naming a file that doesn't exist was accepted" >&2
    exit 1
fi
cat out
grep -q "nor-this" out
test ! -e Makefile

# Either of the two places a CONFIG can live is enough on its own, and
# the default Configfile.local stays optional: nothing here writes one.
echo 'COMPILEOPTS += -DFROM_DIRECTORY' > Configfiles/in-directory
echo 'COMPILEOPTS += -DFROM_DOTTED' > Configfile.dotted
cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
CONFIG      += in-directory
CONFIG      += dotted
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DFROM_DIRECTORY" Makefile
grep -q -- "-DFROM_DOTTED" Makefile
