#include "harness_start.bash"

# An install prefix is an absolute path by definition: it is where the
# installed program will find itself, compiled into it as
# __PCONFIGURE__PREFIX and __PCONFIGURE__LIBEXEC and linked into it as
# the RUNPATH its libraries are found through.  "PREFIX = opt/thing"
# was pasted into the install rules after $(DESTDIR) as though it
# were absolute, while the program was told its prefix is
# "opt/thing", and its RUNPATH became "opt/thing/lib": a library
# search path relative to whatever directory the program happens to
# be run from.  That is a program which doesn't start from anywhere
# but /, and one that loads libraries out of the current directory
# when it does.  It is a line nobody could have meant, so it is
# refused where it was written.
#
# The error says what to write instead, and the one thing it mustn't
# do is guess by sticking a '/' on the front of what was written:
# "~/foo", "./install" and "../x" were relative to a home directory or
# a working directory that pconfigure can't see, and "/~/foo" or
# "/../x" would name a directory nobody meant.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c
echo 'int f(void); int main(void) { return f(); }' > src/main.c

for prefix in "opt/thing" "~/foo" "./install" "../x"
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

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        make $MAKE_ARGS DESTDIR=$tempdir/dest install || true
        echo "a relative PREFIX was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:1" out
    grep -q "PREFIX" out
    grep -q "absolute" out
    grep -q "PREFIX = /opt/thing'" out
    case "$prefix" in
    [~.]*)
        if grep -F "PREFIX = /$prefix" out
        then
            echo "the suggestion is the relative value with a '/' in front" >&2
            exit 1
        fi
        ;;
    esac
    test ! -e Makefile
done
