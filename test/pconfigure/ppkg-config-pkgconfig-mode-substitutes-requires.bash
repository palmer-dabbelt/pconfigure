#include "harness_start.bash"

# "--pkgconfig" is the other half of --have, used by pconfigure's own
# Configfile on its pinclude.pc: instead of flags it prints a sed
# expression that replaces "@@HAVE_NAME@@" in a .pc template with the
# package's name when the package is there, and with nothing when it
# isn't.  That is how a generated .pc gets a "Requires:" line only
# for the optional dependencies the build actually used.
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

mkdir fakebin
cat >fakebin/pkg-config <<'EOF'
#!/bin/bash
for arg in "$@"
do
    if [[ "$arg" == "talloc" ]]
    then
        exit 0
    fi
done
exit 1
EOF
chmod +x fakebin/pkg-config
export PATH="$(pwd)/fakebin:$PATH"

test "$("$ppkg" --optional --have TALLOC talloc --pkgconfig)" \
    = "s/@@HAVE_TALLOC@@/talloc/g"
test "$("$ppkg" --optional --have GONE gone --pkgconfig)" \
    = "s/@@HAVE_GONE@@//g"

# And the same thing in place, as a LINKOPTS on a pkgconfig LIBRARY.
mkdir -p src
cat >Configfile <<EOF
LANGUAGES += pkgconfig

LIBRARIES += pkgconfig/x.pc
LINKOPTS  += \`ppkg-config --optional --have TALLOC talloc --pkgconfig\`
LINKOPTS  += \`ppkg-config --optional --have GONE gone --pkgconfig\`
SOURCES   += x.pc
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: 1
Requires: @@HAVE_TALLOC@@ @@HAVE_GONE@@
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat lib/pkgconfig/x.pc
grep -q "^Requires: talloc *$" lib/pkgconfig/x.pc
grep -q "^Requires: talloc *$" obj/pkgconfig/x.pc

exit 0
