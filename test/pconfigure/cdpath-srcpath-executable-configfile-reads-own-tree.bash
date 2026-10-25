#include "harness_start.bash"

# The other half of what CDPATH does to "cd DIR && exec ./Configfile":
# when an entry of CDPATH that isn't "." has a directory of the same
# name, cd goes there instead.  "--srcpath proj" from a build directory
# then ran some other tree's Configfile -- here one that builds a
# target called "wrong" -- and (once cd's announcement of where it went
# was out of the way) would have configured that.
mkdir -p proj/src elsewhere/proj
cat >proj/Configfile <<'EOF'
#!/bin/sh
echo "LANGUAGES += c"
echo "BINARIES  += right"
echo "SOURCES   += hello.c"
EOF
chmod +x proj/Configfile
echo 'int main(void) { return 0; }' > proj/src/hello.c

cat >elsewhere/proj/Configfile <<'EOF'
#!/bin/sh
echo "LANGUAGES += c"
echo "BINARIES  += wrong"
echo "SOURCES   += hello.c"
EOF
chmod +x elsewhere/proj/Configfile

export CDPATH="$(pwd)/elsewhere"
$PTEST_BINARY --srcpath proj > out 2>&1 || { cat out; exit 1; }
cat out
grep -q '^bin/right:' Makefile
if grep -q 'bin/wrong' Makefile
then
    exit 1
fi
