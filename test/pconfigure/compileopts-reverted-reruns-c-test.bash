#include "harness_start.bash"

# A compiled TESTSRC is a program like any other, linked from objects
# hashed by its options.  Reverting an option used to leave its test
# binary as the in-between build linked it, and the result made from
# that binary with it, so make check went on reporting the failure of
# a build nobody had any more.  Here the test fails only under
# -DVAL=2, and this makes sure going back to -DVAL=1 makes it pass
# again.

mkdir -p src test/app

cat >src/main.c <<'EOS'
int main(void) { return 0; }
EOS

cat >test/app/t.c <<'EOS'
int main(void) { return VAL == 2; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
BINARIES    += app
SOURCES     += main.c
TESTSRC     += t.c
COMPILEOPTS += -DVAL=$1
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS check
test "$(tar -xOf check/app/t.c ptest__return)" = "0"

sleep 2
configure_with 2
make $MAKE_ARGS check || true
test "$(tar -xOf check/app/t.c ptest__return)" = "1"

sleep 2
configure_with 1
make $MAKE_ARGS check || true
test "$(tar -xOf check/app/t.c ptest__return)" = "0"
