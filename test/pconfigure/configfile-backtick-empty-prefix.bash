#include "harness_start.bash"

# PREFIX is where "make install" writes, and "PREFIX =" is refused as a
# line somebody got wrong.  A backtick that answers with nothing --
# "PREFIX = `echo $SOME_UNSET_VARIABLE`" is the shape this takes in
# the wild -- reaches the same empty value by a different road, and an
# install into "$(DESTDIR)//bin" is the root of the filesystem when
# DESTDIR is unset.  It gets the same refusal.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

PREFIX       = `echo $PCONFIGURE_TEST_VARIABLE_THAT_IS_NOT_SET`
BINARIES    += main
SOURCES     += main.c
EOF

unset PCONFIGURE_TEST_VARIABLE_THAT_IS_NOT_SET

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    grep -n "DESTDIR" Makefile | head -5 || true
    echo "PREFIX set to nothing by a backtick was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "printed nothing" out
test ! -e Makefile
