#include "harness_start.bash"

# Run with stdout or stderr closed -- from a cron job, or a wrapper that
# does ">&-" -- the first file pconfigure opens gets that descriptor
# number.  Anything printed to it then lands in that file instead, so
# the warning a Configfile line earns, the header copy run while
# configuring and the Makefile itself all have to come out the same as
# with both open.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
echo '#define X 1' > src/x.h
cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h
HEADERS   += x.h
SOURCES   += x.h
BINARIES  += hello
SOURCES   += hello.c
VERBOSE    = yes
EOF2

$PTEST_BINARY > /dev/null 2>&1
cp Makefile good.mk
find obj include -type f | sort | xargs md5sum > good.sum

for closed in '>&-' '2>&-' '>&- 2>&-'
do
    rm -rf Makefile obj include
    eval "\$PTEST_BINARY $closed"
    diff -u good.mk Makefile
    find obj include -type f | sort | xargs md5sum | diff -u good.sum -
done
make
./bin/hello
