#include "harness_start.bash"

# A relative --phc is a path from where pconfigure was run, the build
# directory, rather than from --srcpath: it's the person typing the
# command who named it, and from where they stood.  The configure-time
# copy and the Makefile's recipe both run it by that name, and both run
# from the build directory.
mkdir -p tree/src build
echo '#define X 1' > tree/src/x.h

cat >tree/Configfile <<'EOF'
LANGUAGES += h
HEADERS   += x.h
SOURCES   += x.h
EOF

cat >build/myphc <<'EOF'
#!/bin/bash
# -i IN -o OUT, the way phc is called.
echo "ran $*" >> phc.log
cp "$2" "$4"
EOF
chmod +x build/myphc

cd build
$PTEST_BINARY --srcpath ../tree --phc ./myphc
cat Makefile
grep -q '^PCONFIGURE_ARGS ?= --srcpath ../tree --phc ./myphc$' Makefile
grep -q 'ran -i ../tree/src/x.h -o include/x.h' phc.log
test -f include/x.h

rm -f include/x.h phc.log
make $MAKE_ARGS
grep -q 'ran -i ../tree/src/x.h -o include/x.h' phc.log
cmp include/x.h ../tree/src/x.h
