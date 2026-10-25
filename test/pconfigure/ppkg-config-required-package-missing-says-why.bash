#include "harness_start.bash"

# ppkg-config used to run pkg-config with its stderr thrown away,
# which is what keeps "--optional" quiet.  Without "--optional" it
# threw it away just the same, so a required package that was missing
# made ppkg-config exit non-zero having said nothing at all: not the
# package's name, not pkg-config's "Package foo was not found in the
# pkg-config search path", not the PKG_CONFIG_PATH hint.  Inside a
# Configfile backtick that silence left pconfigure's own error as the
# only thing said, and pconfigure can't know which package it was.
#
# A fake pkg-config stands in for the real one, so that what it says
# on stderr is known.
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

mkdir fakebin
cat >fakebin/pkg-config <<'EOF'
#!/bin/bash
echo "Package wanted-package was not found in the pkg-config search path." >&2
exit 1
EOF
chmod +x fakebin/pkg-config
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$ppkg" wanted-package --cflags >stdout 2>stderr
status="$?"
set -e
cat stdout
cat stderr

test "$status" != "0"
grep -q "wanted-package" stderr

# ... while --optional stays quiet, which is the point of it.
"$ppkg" --optional wanted-package --cflags >stdout 2>stderr
test ! -s stdout
test ! -s stderr

exit 0
