#include "harness_start.bash"

# The C++ half of compileopts-reverted-define-recompiles-c-binary: a
# COMPILEOPTS taken back to a value an earlier build used names the
# link directory that build left behind, and bin/app, which the build
# in between copied out of another directory, used to be newer than
# that link and so was never copied over.  This makes sure the program
# goes back to the first value.

mkdir -p src

cat >src/main.c++ <<'EOS'
#include <cstdio>
int main() { std::printf("%d\n", VAL); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c++
BINARIES    += app
COMPILEOPTS += -DVAL=$1
SOURCES     += main.c++
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
configure_with 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"

sleep 2
configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"
