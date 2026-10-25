#include "harness_start.bash"

# pconfigure copies a HEADERS' SOURCES into the include directory
# while it configures, when the copy is out of date, so that what
# includes it can be scanned.  That copy is made by phc, whose plain
# "cp" couldn't write through the read-only copy it made of a
# read-only source last time -- so the first reconfigure after the
# source changed aborted, telling whoever ran it to "check that include is a
# directory pconfigure can write".  It is: the file in it is the
# build's own, and replacing it is the build's job.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h
HEADERS   += x.h
SOURCES   += x.h
EOF2

echo 'int x_one(void);' > src/x.h
chmod 444 src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

sleep 1
chmod 644 src/x.h
echo 'int x_two(void);' >> src/x.h
chmod 444 src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
cat include/x.h
grep -q x_two include/x.h
chmod -R u+w include
