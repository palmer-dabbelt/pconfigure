#include "harness_start.bash"

# The same source tree named every way a shell might hand it over:
# with a trailing slash (tab completion adds one), absolute, with a
# "/." and with a doubled slash.  Each has to build from a fresh build
# directory, and none may leave anything behind in the source tree.
mkdir -p tree/src
echo 'int main(void) { return 0; }' > tree/src/hello.c
cat >tree/Configfile <<'EOF'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF
before="$(cd tree && find . | sort)"

n=0
for spelling in ../tree/ "$(pwd)/tree" "$(pwd)/tree/" ../tree/. ../tree//
do
    n=$((n + 1))
    mkdir build$n
    (
        cd build$n
        $PTEST_BINARY --srcpath "$spelling"
        make $MAKE_ARGS
        test -x bin/hello
    )
done

after="$(cd tree && find . | sort)"
test "$before" = "$after"
