#include "harness_start.bash"

# ppkg-config drops the "-L/usr/lib" and "-L/usr/lib64" a package's
# .pc sometimes carries, since those are directories the linker
# searches anyway.  It does that with
#
#     sed 's^-L/usr/lib^^g'
#
# which removes those characters wherever they start a longer word
# too.  "-L/usr/lib/x86_64-linux-gnu/openmpi/lib" -- a real directory
# on a Debian machine, and nothing the linker searches by default --
# comes out as "/x86_64-linux-gnu/openmpi/lib", a bare path the
# compiler driver takes for an input file.  "-L/usr/lib64/openmpi/lib"
# goes the same way.  The search path the package asked for is gone,
# and the link line has a word on it that fails the link.
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

FAKE_PKG_CONFIG_OUTPUT="-L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi" \
    "$ppkg" ompi --libs >debian.out
cat debian.out
grep -q -- "^-L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi$" debian.out

FAKE_PKG_CONFIG_OUTPUT="-L/usr/lib64/openmpi/lib -lmpi" \
    "$ppkg" ompi --libs >fedora.out
cat fedora.out
grep -q -- "^-L/usr/lib64/openmpi/lib -lmpi$" fedora.out

# The ones it means to drop still go.
FAKE_PKG_CONFIG_OUTPUT="-L/usr/lib -L/usr/lib64 -lz" \
    "$ppkg" zlib --libs >plain.out
cat plain.out
if grep -q -- "-L/usr/lib" plain.out
then
    exit 1
fi
grep -q -- "-lz" plain.out

exit 0
