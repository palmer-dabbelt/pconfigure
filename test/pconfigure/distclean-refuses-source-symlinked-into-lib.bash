#include "harness_start.bash"

# "make distclean" is an "rm -rf 'lib'", and rm follows a symlink it
# meets partway along a path.  A source directory "src" that is a
# symlink to "lib/src" reads as an ordinary name nowhere near "lib",
# but the recipe takes the real files all the same and leaves a
# dangling "src" behind.  The SUBPROJECTS rule asks its question of
# the resolved directory for the same reason, so this one does too.
mkdir -p lib/src
ln -s lib/src src
echo 'int main(void) { return 0; }' > lib/src/main.c

cat >Configfile <<'EOF'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out
grep -q "^\./Configfile:3 'SOURCES += main.c'" configure.out
grep -q "'src/main.c' resolves to '[^']*/lib/src/main.c', which is inside '[^']*/lib', where libraries go" configure.out
test ! -e Makefile
test -f lib/src/main.c

exit 0
