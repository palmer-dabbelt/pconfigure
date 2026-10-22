#include "harness_start.bash"

top="$tempdir"

# BINARIES and SOURCES are the commands a '#', ':', '=', ';' or quote
# in a name was first found in, but they aren't the only ones whose value
# the language backends write onto a rule line and paste bare into a
# recipe: a LIBRARIES, a LIBEXECS, a TESTS, a TESTSRC, a HEADERS and a
# HEADERSRC are all target or source names in exactly the same way.
# Each is asked here with a different character, so that between them
# and the BINARIES tests every character is refused somewhere other
# than the one place it was first noticed.
refused() {
    local dir="$1" line="$2" char="$3"

    if (cd $top/$dir && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/$dir.out 2>&1
    then
        cat $top/$dir.out
        echo "$dir: a name with a '$char' in it was accepted" >&2
        exit 1
    fi
    cat $top/$dir.out
    grep -q "Configfile:$line" $top/$dir.out
    grep -qF "has a '$char' in it" $top/$dir.out
    test ! -e $top/$dir/Makefile
}

project() {
    mkdir -p $top/$1/src
    echo 'int main(void) { return 0; }' > $top/$1/src/main.c
    cat > $top/$1/Configfile
}

project libraries <<'EOF'
LANGUAGES   += c
LIBRARIES   += lib"quoted".so
SOURCES     += main.c
EOF
refused libraries 2 '"'

project libexecs <<'EOF'
LANGUAGES   += c
LIBEXECS    += helper:one
SOURCES     += main.c
EOF
refused libexecs 2 ':'

project tests <<'EOF'
LANGUAGES   += c
BINARIES    += hello
SOURCES     += main.c
TESTS       += hello=check
EOF
refused tests 4 '='

project testsrc <<'EOF'
LANGUAGES   += c
BINARIES    += hello
SOURCES     += main.c
TESTSRC     += it's.c
EOF
refused testsrc 4 "'"

project headers <<'EOF'
LANGUAGES   += c
LIBRARIES   += libhello.so
HEADERS     += hello#world.h
SOURCES     += main.c
EOF
refused headers 3 '#'

project headersrc <<'EOF'
LANGUAGES   += c
LIBRARIES   += libhello.so
HEADERSRC   += hello:world.h
SOURCES     += main.c
EOF
refused headersrc 3 ':'

# The shell's half of the list is asked of every name too, not just of
# a BINARIES: a ';' in a LIBRARIES is the start of a recipe to make, and
# a '&' in a SOURCES is the end of a command to the shell.
project libraries-semicolon <<'EOF'
LANGUAGES   += c
LIBRARIES   += libhello;world.so
SOURCES     += main.c
EOF
refused libraries-semicolon 2 ';'

project sources-ampersand <<'EOF'
LANGUAGES   += c
BINARIES    += hello
SOURCES     += ma&in.c
EOF
refused sources-ampersand 3 '&'

# And the other side of the line: the same characters in a value that
# is a command line rather than a name are nobody's business here.  A
# COMPILEOPTS defining a macro with an '=', a ':' and a '#' in it, and
# a target name built only out of the characters that are safe, have
# to go on configuring and building exactly as they did.
mkdir -p $top/fine/src
cat > $top/fine/src/main.c <<'EOF'
#define STR(x) #x
#define XSTR(x) STR(x)
static const char s[] = XSTR(GREETING);
int main(void) { return !(sizeof(s) == 6 && s[1] == ':' && s[3] == '#'); }
EOF
cat > $top/fine/Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += hello-world_1.0
COMPILEOPTS += -DGREETING=a:b#c
SOURCES     += main.c
EOF
(cd $top/fine && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd $top/fine && make $MAKE_ARGS)
$top/fine/bin/hello-world_1.0
