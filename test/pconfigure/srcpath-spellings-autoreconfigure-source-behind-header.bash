#include "harness_start.bash"

# The same as srcpath-spellings-build-source-behind-header, for a tree
# where pdeps does the walk rather than pconfigure.  It kept its own
# copy of the comparison, and it is read back out of the context file
# pconfigure wrote, in whatever spelling SRCPATH left it.
mkdir -p tree/src
cat >tree/src/hello.c <<'EOF'
#include "other.h"
int main(void) { return other(); }
EOF
echo 'int other(void);' > tree/src/other.h
echo 'int other(void) { return 0; }' > tree/src/other.c
cat >tree/Configfile <<'EOF'
AUTORECONFIGURE = true
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
