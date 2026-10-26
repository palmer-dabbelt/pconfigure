#include "harness_start.bash"

# A COMPILER line added by an edit changes the command every object is
# built with, while no source changed and no object's name has to.
# Under AUTORECONFIGURE the edit reconfigures, and the reconfigured
# build has to compile again with the new compiler rather than keep the
# objects the old one made.

mkdir -p src

cat >wrapped-cc <<EOS
#!/bin/bash
echo "\$@" >> "$(pwd)/wrapped.log"
exec cc "\$@"
EOS
chmod +x wrapped-cc

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test ! -e wrapped.log

sleep 1
sed -i "s@^LANGUAGES .*@&\nCOMPILER         = $(pwd)/wrapped-cc@" Configfile
cat Configfile

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
cat wrapped.log
grep -q 'src/main\.c' wrapped.log
./bin/main

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
grep -q "Nothing to be done" third.log
