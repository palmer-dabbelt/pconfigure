#include "harness_start.bash"

# The case the manual names for a CONFIG_DEPS without AUTORECONFIGURE:
# "a project that keeps its own committed Makefile beside the generated
# one supplies the recipe there".  A BOOTSTRAP project is exactly that
# -- its committed Makefile has the recipe that writes
# Makefile.pconfigure -- so a CONFIG_DEPS directory gaining a file should
# be a reconfigure.  The prerequisite used to be written only under
# AUTORECONFIGURE, so the executable CONFIG that enumerates the
# directory went on describing the tree as it was before the file
# appeared, and the new program was never built.

here="$(pwd)"

mkdir -p src tests Configfiles vendor/pconfigure/src

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

cat >Configfile <<'EOC'
BOOTSTRAP       = vendor/pconfigure
LANGUAGES      += c
CONFIG         += programs
EOC

# One program per file in tests/, which is the shape CONFIG_DEPS is
# for: the directory is the input, and no Configfile changes when a
# file is added to it.
cat >Configfiles/programs <<'EOC'
#!/bin/bash
echo "CONFIG_DEPS += tests"
for f in tests/*; do
    [ -e "$f" ] || continue
    echo "BINARIES += ${f##*/}"
    echo "SOURCES  += hello.c"
done
EOC
chmod +x Configfiles/programs

echo 'int main(void) { return 0; }' > src/hello.c
touch tests/first

$PTEST_BINARY $PCONFIGURE_ARGS
rm -rf Makefile.pconfigure obj bin configures
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
test -x bin/first

sleep 1
touch tests/second
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x bin/second
