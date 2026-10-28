#include "harness_start.bash"

# The rule that bootstraps a vendored pconfigure enters it with
# "cd $(PCONFIGURE_SRCPATH)", and that path is relative -- it is the
# BOOTSTRAP line as the Configfile spelled it.  A relative cd is the
# case CDPATH applies to, and make hands its own environment to every
# recipe, so a developer with a CDPATH exported from their shell's rc
# file had the cd looked up along it.  Where an entry of it held a
# directory of the same name -- a second checkout of the same project
# is the obvious way to get one -- the cd went there instead, and the
# fresh build ran somebody else's bootstrap.sh.
#
# The stand-in vendored tree is the one bootstrap-quiet.bash uses: what
# is under test is the Makefile pconfigure writes, not its own
# bootstrap.sh.
here="$(pwd)"

mkdir -p src vendor/pconfigure/src

cat >vendor/pconfigure/src/pconfigure.bash <<EOF
exec "$PTEST_BINARY" "\$@"
EOF

cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash

BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF

cat >vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash -e
echo ran >> "$here/bootstraps"
mkdir -p bin
{ echo '#!/bin/bash'; cat src/pconfigure.bash; } > bin/pconfigure
chmod +x bin/pconfigure
echo "# bootstrapped" > Makefile
EOF
chmod +x vendor/pconfigure/bootstrap.sh

# The decoy says so and fails, so that taking it is visible both in
# the file it writes and in the build going wrong.
mkdir -p decoy/vendor/pconfigure
cat >decoy/vendor/pconfigure/bootstrap.sh <<EOF
#!/bin/bash
echo ran >> "$here/decoy-bootstraps"
exit 1
EOF
chmod +x decoy/vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOF
BOOTSTRAP   = vendor/pconfigure

LANGUAGES  += c

BINARIES   += hello
SOURCES    += hello.c
EOF

cat >src/hello.c <<EOF
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
rm -rf Makefile.pconfigure obj bin check
rm -rf vendor/pconfigure/Makefile vendor/pconfigure/bin vendor/pconfigure/obj

# The fresh checkout, built by somebody whose shell exports a CDPATH
# that reaches the decoy before it reaches ".".
export CDPATH="$here/decoy:."
make $MAKE_ARGS > fresh.out 2>&1 || { cat fresh.out; exit 1; }
cat fresh.out

test ! -e decoy-bootstraps
test "$(wc -l < bootstraps | tr -d ' ')" -eq 1
test -x bin/hello
