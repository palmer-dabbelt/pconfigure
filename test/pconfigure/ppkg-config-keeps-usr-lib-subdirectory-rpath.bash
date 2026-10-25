#include "harness_start.bash"

# The same substring stripping that eats the front of a
# "-L/usr/lib/..." eats the front of an rpath under /usr/lib:
# "-Wl,-rpath,/usr/lib/foo" loses its "-Wl,-rpath,/usr/lib" and is
# handed to the compiler as the bare path "/foo".  An rpath is there
# because the library is *not* in a directory the loader searches,
# so dropping it builds a binary that can't find its library at run
# time, and the leftover word breaks the link before that.
#
# A "-L/usr/libexec/..." (nobody's idea of a default search path)
# loses its "-L/usr/lib" just the same and becomes "exec/...".
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

# A pkg-config that answers with exactly what the test wants, so that
# what ppkg-config does to the answer is all that is being looked at.
mkdir fakebin
cat >fakebin/pkg-config <<EOF
#!/bin/bash
echo "\$FAKE_PKG_CONFIG_OUTPUT"
EOF
chmod +x fakebin/pkg-config
export PATH="$(pwd)/fakebin:$PATH"

FAKE_PKG_CONFIG_OUTPUT="-Wl,-rpath,/usr/lib/foo/private -L/opt/foo/lib -lfoo" \
    "$ppkg" foo --libs >rpath.out
cat rpath.out
grep -q -- "-Wl,-rpath,/usr/lib/foo/private" rpath.out

FAKE_PKG_CONFIG_OUTPUT="-L/usr/libexec/foo -lfoo" \
    "$ppkg" foo --libs >libexec.out
cat libexec.out
grep -q -- "^-L/usr/libexec/foo -lfoo$" libexec.out

exit 0
