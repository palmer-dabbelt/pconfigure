#include "harness_start.bash"

# Under AUTORECONFIGURE a tree that bootstraps its own pconfigure puts
# that pconfigure on the reconfigure rule, by its absolute path inside a
# "$(wildcard ...)", so that an edit to the tool's source -- which
# rebuilds it -- reruns it (see bootstrap-tool-source-change-reconfigures-once).
# The path is this checkout's, and in a checkout whose directory is
# named like "proj[2]" the brackets are a character class to the glob
# unless they are quoted: the wildcard matches nothing, and the rebuilt
# tool never configures anything.

mkdir 'checkout[2]'
cd 'checkout[2]'

here="$(pwd)"

mkdir -p src vendor/pconfigure/src

# A stand-in for the vendored pconfigure, as in bootstrap.bash: an
# ordinary pconfigure project whose one binary is the real pconfigure
# wearing a different path, and that logs every configure it runs.
cat >vendor/pconfigure/src/pconfigure.bash <<EOS
echo ran >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOS

cat >vendor/pconfigure/Configfile <<EOS
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOS

cat >vendor/pconfigure/bootstrap.sh <<EOS
#!/bin/bash -e
mkdir -p bin
{ echo "#!/bin/bash"; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOS
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOS
AUTORECONFIGURE = true
BOOTSTRAP       = vendor/pconfigure
LANGUAGES      += c
BINARIES       += hello
SOURCES        += hello.c
EOS

echo "int main(void) { return 0; }" > src/hello.c

# Written once, then built from nothing but the committed Makefile the
# way a fresh checkout is.
$PTEST_BINARY $PCONFIGURE_ARGS
rm -rf Makefile.pconfigure obj bin configures
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -x bin/hello

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
test "$(wc -l < configures | tr -d ' ')" -eq 1

sleep 1
echo "# edited" >> vendor/pconfigure/src/pconfigure.bash
make $MAKE_ARGS > rebuilt.log 2>&1 || { cat rebuilt.log; exit 1; }
cat rebuilt.log
make $MAKE_ARGS > after.log 2>&1 || { cat after.log; exit 1; }
cat after.log
test "$(wc -l < configures | tr -d ' ')" -eq 2
