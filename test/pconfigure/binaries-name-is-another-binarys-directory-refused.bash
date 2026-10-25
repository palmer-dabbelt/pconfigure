#include "harness_start.bash"

# "BINARIES += tools" is the file bin/tools, and "BINARIES += tools/run"
# needs bin/tools to be a directory.  Both can't be, so this is two
# targets fighting over one path in the same way two BINARIES with the
# same name are, and it is refused while configuring, naming both
# lines.  It used to get through: whichever rule ran second found
# bin/tools the wrong kind of thing, the "mv" that finishes the copy
# moved the program into the directory as bin/tools/tools.tmp, and
# make reported success with bin/tools a directory.  Either line can
# come first, so both orders are tried, and the later line is the one
# refused.
mkdir -p src
echo 'int main(void) { return 0; }' > src/a.c
echo 'int main(void) { return 0; }' > src/b.c

for order in "tools tools/run" "tools/run tools"
do
    set -- $order
    rm -rf Makefile obj bin
    cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += $1
SOURCES   += a.c

BINARIES  += $2
SOURCES   += b.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        make $MAKE_ARGS || true
        find bin
        echo "'$1' and '$2' were both accepted" >&2
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:6 'BINARIES += $2'" configure.out
    grep -qF "Configfile:3 'BINARIES += $1'" configure.out
    if test "$1" = tools; then file=3 inside=6; else file=6 inside=3; fi
    grep -qF "'bin/tools' is the file built by ./Configfile:$file 'BINARIES += tools'," configure.out
    grep -qF "'bin/tools/run', built by ./Configfile:$inside 'BINARIES += tools/run', needs it to be a directory" configure.out
    test ! -e Makefile
done
