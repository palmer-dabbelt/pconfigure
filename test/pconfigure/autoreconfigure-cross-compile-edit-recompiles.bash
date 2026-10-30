#include "harness_start.bash"

# CROSS_COMPILE added by an edit renames every tool the build runs.
# Under AUTORECONFIGURE that edit reconfigures, and the objects the
# host compiler made must not be reused: the source is compiled and the
# program linked again by the prefixed compiler.

mkdir -p src tools

cat >tools/fake-gcc <<EOS
#!/bin/bash
echo "\$@" >> "$(pwd)/fake.log"
exec cc "\$@"
EOS
chmod +x tools/fake-gcc
export PATH="$(pwd)/tools:$PATH"

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test ! -e fake.log

sleep 1
{ echo 'CROSS_COMPILE    = fake-'; cat Configfile; } > Configfile.new && mv Configfile.new Configfile

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
cat fake.log
grep -q -- '-c src/main\.c' fake.log
grep -q 'static\.o' fake.log
./bin/main

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
grep -q "Nothing to be done" third.log
