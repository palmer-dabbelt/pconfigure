#include "harness_start.bash"

# This is a guard rather than a bug report: everything here is refused
# already, and has to stay refused.
#
# A backtick that printed nothing leaves its line with no value, and
# what that means depends on the command: some can be given nothing
# and some can't.  But that question only makes sense of a command
# that exists and was written with an operator it takes.  Whether a
# typo is reported can't depend on what some shell command happened
# to print: "COMPILEOPT += -O2" is refused as an unknown command, and
# "COMPILEOPT += `pkg-config --cflags zlib`" has to be refused just
# the same on a machine where zlib needs no flags, rather than being
# read as a line that adds nothing to nothing.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

refused() {
    local line="$1"
    rm -f out Makefile
    cat >Configfile <<EOF
LANGUAGES   += c
$line
BINARIES    += main
SOURCES     += main.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
    then
        cat out
        echo "'$line' was accepted" >&2
        exit 1
    fi
    cat out
    test ! -e Makefile
}

# A misspelled command is an unknown command, whatever its value came
# to -- and it's the name that's wrong, not the value, so the refusal
# mustn't be the one about a command that printed nothing.
refused 'COMPILEOPT += `true`'
grep -q "COMPILEOPT" out
if grep -q "printed nothing" out
then
    echo "an unknown command was blamed on its empty value" >&2
    exit 1
fi

refused 'COMPILEOPT = `true`'
if grep -q "printed nothing" out
then
    echo "an unknown command was blamed on its empty value" >&2
    exit 1
fi

# A name in brackets that's never closed is no command at all.
refused 'COMPILEOPTS[x += `true`'
grep -q "never closes it" out

# An operator the command doesn't take is the mistake it is when the
# value is typed out, both for a list that could otherwise be given
# nothing and for a command that can't.
refused 'COMPILEOPTS = `true`'
grep -q "only supports '+='" out

refused 'LIBDIR += `true`'
