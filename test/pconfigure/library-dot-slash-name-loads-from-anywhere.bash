test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# "./libf.so" is a spelling of "libf.so", and a DEPLIBS finds it
# through the same -lf either way.  So the soname, which every program
# linked against the library copies into its NEEDED, has to be
# "libf.so" too: a NEEDED of "./libf.so" is read by the dynamic loader
# as a path from whatever directory the program was started in, never
# consulting the runpath, and the program would then run from lib/ and
# nowhere else.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c
echo 'int f(void); int main(void) { return f(); }' > src/main.c

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += ./libf.so
SOURCES   += f.c

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

readelf -d lib/libf.so > libf.dynamic
cat libf.dynamic
grep -q '(SONAME).*\[libf\.so\]' libf.dynamic

readelf -d bin/main > main.dynamic
cat main.dynamic
grep -q '(NEEDED).*\[libf\.so\]' main.dynamic

./bin/main
(cd / && $tempdir/bin/main)
