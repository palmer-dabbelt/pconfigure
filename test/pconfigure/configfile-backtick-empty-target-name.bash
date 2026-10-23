#include "harness_start.bash"

# A command in backticks that prints nothing can add nothing to a list
# of options, and that's fine: "COMPILEOPTS += `pkg-config --cflags
# zlib`" does exactly that for a library in the compiler's own paths.
# A target is not a list of options.  "BINARIES +=" starts a new
# binary, and everything below it belongs to that binary; one with no
# name is the bare "BINARIES +=" that's refused when typed.  Read as
# a line that does nothing instead, it would leave the SOURCES under
# it attached to whatever target came before -- here, b.c built into
# binary "a" with nothing anywhere to say so.
mkdir -p src
echo 'int main(void) { return 0; }' > src/a.c
echo 'int b(void) { return 0; }' > src/b.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += a
SOURCES     += a.c
BINARIES    += `true`
SOURCES     += b.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    grep -n "b\.c" Makefile || true
    echo "a BINARIES that a backtick emptied was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:5" out
grep -q "printed nothing" out
test ! -e Makefile

# And the same for every other command that names something rather
# than adding options to it.  Each of these is refused when the value
# is left off by hand.
for line in \
    'LIBRARIES += `true`' \
    'TESTS += `true`' \
    'HEADERS += `true`' \
    'SOURCES += `true`' \
    'LANGUAGES += `true`' \
    'DEPLIBS += `true`' \
    'COMPILER = `true`'
do
    rm -f out Makefile
    cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += a
$line
SOURCES     += a.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
    then
        cat out
        echo "'$line' was accepted" >&2
        exit 1
    fi
    cat out
    grep -q "Configfile:4" out
    grep -q "printed nothing" out
    test ! -e Makefile
done
