#include "harness_start.bash"

# A source found behind a header is built into whatever read the
# header, and telling whether it is one of this project's own meant
# comparing it with the source directory as strings.  What the include
# search finds has been tidied up on its way out and the source
# directory hasn't, so "--srcpath tree/", which is what tab completion
# writes, read as "tree//src" against "tree/src": nothing was found
# behind any header, and the link stopped on undefined symbols.
#
# A library wouldn't say so on Linux, where one can be linked with
# symbols missing and the program it goes into makes up the difference
# by accident, so this is a program.
mkdir -p tree/src
cat >tree/src/hello.c <<'EOF'
#include "other.h"
int main(void) { return other(); }
EOF
echo 'int other(void);' > tree/src/other.h
echo 'int other(void) { return 0; }' > tree/src/other.c
cat >tree/Configfile <<'EOF'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF

n=0
for spelling in ../tree ../tree/ "$(pwd)/tree" "$(pwd)/tree/" ../tree/. ../tree//
do
    n=$((n + 1))
    mkdir build$n
    (
        cd build$n
        $PTEST_BINARY --srcpath "$spelling"
        make $MAKE_ARGS
        ./bin/hello
    )
done

# And the source tree named from inside it, which is the same directory
# as this one under a name that doesn't look like it.
(
    cd tree
    for spelling in . ./ "$(pwd)" "$(pwd)/"
    do
        $PTEST_BINARY --srcpath "$spelling"
        make $MAKE_ARGS
        ./bin/hello
        make $MAKE_ARGS clean
    done
)
