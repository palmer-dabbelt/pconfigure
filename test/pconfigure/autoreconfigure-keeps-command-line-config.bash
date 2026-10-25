#include "harness_start.bash"

# "--config NAME" is documented as exactly a "CONFIG += NAME" ahead of
# every Configfile, which is what lets one tree be configured two ways
# without editing anything in it.  Under AUTORECONFIGURE the build then
# re-runs pconfigure on its own whenever a Configfile changes -- and
# whatever it re-runs has to be the configuration somebody asked for,
# not the one they would have got by typing "pconfigure" bare.  A tree
# configured with "--config extra" that quietly loses everything
# Configfiles/extra declared the first time somebody edits a comment
# in the Configfile is a build that changed shape with nobody asking.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src Configfiles

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

cat >Configfiles/extra <<'EOF'
LANGUAGES       += c
BINARIES        += extra
SOURCES         += extra.c
EOF

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/extra.c

$PTEST_BINARY $PCONFIGURE_ARGS --config extra
make $MAKE_ARGS
test -x bin/extra
grep -q '^bin/extra:' Makefile
grep -q '\$(wildcard Configfiles/extra)' Makefile

# An edit that means nothing, which is the case that makes the point:
# the Configfiles say exactly what they said before, so the Makefile
# has no business saying anything different.
sleep 1
echo "# a comment" >> Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log

grep -q '^bin/extra:' Makefile
grep -q '\$(wildcard Configfiles/extra)' Makefile

exit 0
