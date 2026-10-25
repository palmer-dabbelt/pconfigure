#include "harness_start.bash"

# A "--config" names a Configfile of its own, so a run that has one is
# not a run with nothing to read even when none of the four default
# Configfiles is there: a tree that keeps every configuration under
# Configfiles/ and picks one on the command line configures from it.
mkdir src
echo 'int main(void) { return 0; }' > src/hello.c
mkdir Configfiles
cat >Configfiles/release <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS --config release
make
./bin/hello
