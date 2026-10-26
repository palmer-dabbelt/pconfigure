#include "harness_start.bash"

# Under AUTORECONFIGURE a tree that bootstraps its own pconfigure puts
# that pconfigure on the reconfigure rule too, named by its absolute
# path inside a "$(wildcard ...)" so that rebuilding the tool reruns
# it.  That path is this checkout's, so it has to be spelled for make:
# in a checkout whose directory has a ':' in its name -- a "proj:v2"
# next to the "proj" it was copied from -- a ':' make read as a second
# target separator, as soon as the tool exists, would stop the very make
# that bootstraps it part way through, and every make after it, on
# "target pattern contains no '%'".  The relative paths everywhere else
# in the Makefile never see the ':'.

mkdir 'checkout:v2'
cd 'checkout:v2'

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

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "Nothing to be done" second.log
