#include "harness_start.bash"

# A BOOTSTRAP project under AUTORECONFIGURE keeps the reconfigure rule's
# recipe in its committed Makefile and the prerequisites in
# Makefile.pconfigure.  A CONFIG_DEPS is one of those prerequisites like
# any Configfile: a file appearing in the directory it names is a
# configure by the vendored pconfigure, and the tree then settles.

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
AUTORECONFIGURE = true
BOOTSTRAP       = vendor/pconfigure
LANGUAGES      += c
CONFIG         += programs
EOC

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
grep -q '^Makefile.pconfigure:.*\$(wildcard tests)' Makefile.pconfigure

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
before="$(wc -l < configures)"

sleep 1
touch tests/second
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x bin/second
test "$(wc -l < configures)" -eq $((before + 1))

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
grep -q "Nothing to be done" third.log
