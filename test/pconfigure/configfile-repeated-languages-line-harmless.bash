#include "harness_start.bash"

# Saying "LANGUAGES += c" a second time -- two Configfiles pasted
# together, or a CONFIG that states the languages it needs -- adds
# nothing: there's still one C, sources aren't claimed twice, nothing
# warns about several languages matching, and the options given under
# the first line still reach the compile.
mkdir -p src Configfiles
cat >src/main.c <<'EOF'
#ifndef FROM_FIRST
#error options from under the first LANGUAGES line were lost
#endif
int main(void) { return 0; }
EOF

cat >Configfiles/extra <<'EOF'
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
EOF

cat >Configfile <<'EOF'
LANGUAGES   += c
COMPILEOPTS += -DFROM_FIRST
CONFIG      += extra
EOF

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out
if grep -qi "multiple" out
then
    exit 1
fi
make $MAKE_ARGS
./bin/main
test $(grep -c '^	@${CC} -x c ' Makefile) -eq 1
