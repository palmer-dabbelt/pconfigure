#include "harness_start.bash"

# "BINARIES += main/" is an easy slip -- a name typed after a
# tab-completion of a directory -- and it used to be pasted onto bin/
# as written, so the copy into bin/ became a "cp" to bin/main/.tmp
# followed by an "mv" of that file onto itself, and the build stopped
# on "mv: ... are the same file", which says nothing about the
# Configfile.  The slash adds nothing a target's name could mean, so
# it is taken off and bin/main is built; the same goes for every
# other command that names a linked target.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

for command in BINARIES LIBEXECS TESTEXECS
do
    case "$command" in
    BINARIES)  dir=bin ;;
    LIBEXECS)  dir=libexec ;;
    TESTEXECS) dir=testexec ;;
    esac

    rm -rf Makefile obj bin libexec testexec
    cat >Configfile <<EOF
LANGUAGES += c

$command += main/
SOURCES   += main.c
EOF
    cat Configfile

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    test -f $dir/main
    ./$dir/main
done
