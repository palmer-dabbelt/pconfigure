#include "harness_start.bash"

# Under AUTORECONFIGURE the Configfile edit is noticed by make itself,
# and the reconfigure it runs writes the same Makefile a hand-run one
# would.  So the revert had the same hole: the option put back named
# the link an earlier build left, and bin/app from the build in
# between was kept.  This makes sure the revert is picked up here too,
# in the shape somebody bisecting a flag hits, editing and running make
# with nothing else in between.

mkdir -p src

cat >src/main.c <<'EOS'
#include <stdio.h>
int main(void) { printf("%d\n", VAL); return 0; }
EOS

write_configfile() {
    cat >Configfile <<EOC
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += app
COMPILEOPTS     += -DVAL=$1
SOURCES         += main.c
EOC
}

write_configfile 1
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
write_configfile 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"

sleep 2
write_configfile 1
make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
grep -q "^PCONFIGURE$" third.log
test "$(./bin/app)" = "1"
