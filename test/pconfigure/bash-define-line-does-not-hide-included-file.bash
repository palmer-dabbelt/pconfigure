#include "harness_start.bash"

# pbashc reads no "#define": the names a script's "#ifdef"s ask about
# are the "-D"s in its COMPILEOPTS and nothing else, so a "#define"
# line is a comment to it, and the "#ifndef QUIET" below is taken and
# extra.bash pasted in.  The dependency scan read the "#define" as C
# would, decided QUIET was defined, and left extra.bash off the
# script's prerequisites -- so editing extra.bash rebuilt nothing and
# bin/app went on running the old copy.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += app
SOURCES     += app.bash
EOF

cat >src/app.bash <<'EOF'
#!/bin/bash
#define QUIET
#ifndef QUIET
#include "extra.bash"
#endif
echo main
EOF
echo 'echo extra-one' > src/extra.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app | grep -qx extra-one

sleep 1
echo 'echo extra-two' > src/extra.bash
make $MAKE_ARGS
./bin/app
./bin/app | grep -qx extra-two
