#include "harness_start.bash"

# The manual says a BOOTSTRAP tree takes PCONFIGURE_ARGS on its first
# configure too, "make PCONFIGURE_ARGS='--config debug'" being the
# example.  Under AUTORECONFIGURE the same tree re-runs pconfigure
# from inside a plain "make" whenever a Configfile changes, and that
# make was not given the options -- so what it runs has to come from
# somewhere other than its own command line, or the tree configured
# with "--config extra" loses Configfiles/extra the first time a
# Configfile is touched.

here="$(pwd)"

mkdir -p src vendor/pconfigure/src Configfiles

# A stand-in for a vendored pconfigure, which runs the one under test.
cat >vendor/pconfigure/src/pconfigure.bash <<EOF
echo "\$*" >> "$here/configures"
exec "$PTEST_BINARY" "\$@"
EOF

cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

cat >vendor/pconfigure/bootstrap.sh <<EOF
mkdir -p bin
{ echo '#!/bin/bash'; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOF
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOF
AUTORECONFIGURE  = true
BOOTSTRAP        = vendor/pconfigure

LANGUAGES       += c

BINARIES        += hello
SOURCES         += hello.c
EOF

cat >Configfiles/extra <<EOF
LANGUAGES       += c

BINARIES        += extra
SOURCES         += extra.c
EOF

echo 'int main(void) { return 0; }' > src/hello.c
echo 'int main(void) { return 0; }' > src/extra.c

# The committed Makefile, then a fresh checkout of it.
$PTEST_BINARY $PCONFIGURE_ARGS
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

make $MAKE_ARGS PCONFIGURE_ARGS="--config extra"
cat configures
test -x bin/extra
grep -q '^bin/extra:' Makefile.pconfigure

sleep 1
echo "# a comment" >> Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
cat configures
test "$(wc -l < configures)" -eq 2

grep -q '^bin/extra:' Makefile.pconfigure

exit 0
