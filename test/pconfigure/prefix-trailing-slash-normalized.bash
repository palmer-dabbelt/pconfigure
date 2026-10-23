#include "harness_start.bash"

# "PREFIX = /opt/thing/" and "PREFIX = /opt/thing" are the same
# directory, and a program built under either should be told the same
# thing about where it lives.  Pasting the value in verbatim compiled
# "/opt/thing/" into __PCONFIGURE__PREFIX and "/opt/thing//libexec"
# into __PCONFIGURE__LIBEXEC, and linked "/opt/thing//lib" in as the
# RUNPATH -- strings that compare unequal to the ones a program built
# from the other spelling sees, and that a program comparing paths
# (or a packager grepping for its prefix) trips over.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c
cat >src/main.c <<'EOF'
#include <stdio.h>
int f(void);
int main(void)
{
    puts(__PCONFIGURE__PREFIX);
    puts(__PCONFIGURE__LIBEXEC);
    return f();
}
EOF

printf '/opt/thing\n/opt/thing/libexec\n' > expected

for prefix in "/opt/thing/" "/opt//thing" "/opt/thing//"
do
    cat >Configfile <<EOF
PREFIX     = $prefix

LANGUAGES += c

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF
    cat Configfile

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    ./bin/main > out
    cat out
    diff -u expected out

    # The prefix only reaches the RUNPATH of what gets installed: the
    # copy in bin/ finds its libraries relative to itself, so it can be
    # run before anything is installed.  And the RUNPATH is an ELF
    # thing; a Mach-O binary says the same with an LC_RPATH this
    # doesn't go looking for.
    rm -rf dest
    make $MAKE_ARGS DESTDIR=$tempdir/dest install
    test -x dest/opt/thing/bin/main
    if test "$(uname -s)" != "Darwin"
    then
        readelf -d dest/opt/thing/bin/main > main.dynamic
        cat main.dynamic
        grep -q '\[/opt/thing/lib\]' main.dynamic
        if grep -q '//' main.dynamic
        then
            echo "a '//' leaked into the RUNPATH" >&2
            exit 1
        fi
    fi

    make $MAKE_ARGS clean
done
