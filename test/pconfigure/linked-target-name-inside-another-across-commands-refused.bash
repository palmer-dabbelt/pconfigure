#include "harness_start.bash"

# A file and a directory at one path is a collision whichever commands
# the two targets came from, as long as they land in the same output
# directory: a TESTEXECS named "t" and a TESTEXECS named "t/one" fight
# over testexec/t, and two LIBRARIES fight over lib/libx.so the same
# way.  A BINARIES "tools" beside a LIBEXECS "tools/run" is fine,
# though, since one is under bin/ and the other under libexec/.
mkdir -p src
echo 'int main(void) { return 0; }' > src/a.c
echo 'int main(void) { return 0; }' > src/b.c

for pair in "TESTEXECS:t TESTEXECS:t/one" "LIBRARIES:libx.so LIBRARIES:libx.so/liby.so"
do
    set -- $pair
    rm -rf Makefile obj bin lib testexec
    cat >Configfile <<EOF
LANGUAGES += c

${1%%:*} += ${1#*:}
SOURCES   += a.c

${2%%:*} += ${2#*:}
SOURCES   += b.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        echo "'$1' and '$2' were both accepted" >&2
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:6 '${2%%:*} += ${2#*:}'" configure.out
    grep -qF "Configfile:3 '${1%%:*} += ${1#*:}'" configure.out
    grep -qF "to be a directory" configure.out
done

rm -rf Makefile obj bin lib libexec
cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += tools
SOURCES   += a.c

LIBEXECS  += tools/run
SOURCES   += b.c
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f bin/tools
test -f libexec/tools/run
