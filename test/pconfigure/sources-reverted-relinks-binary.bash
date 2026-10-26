#include "harness_start.bash"

# A program switched from one SOURCES to another and back again.  The
# first source's object is still where the first build left it and is
# older than the program, so this relinks only because the link's
# inputs are recorded in a file the configure rewrites when they
# change.  Options hashed into the object's name have no such record,
# which is the difference this pins down from the SOURCES side.

mkdir -p src

echo 'int main(void) { return 1; }' > src/one.c
echo 'int main(void) { return 2; }' > src/two.c

configure_with() {
    cat >Configfile <<EOC
LANGUAGES += c
BINARIES  += app
SOURCES   += $1
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

status() {
    ./bin/app && echo 0 || echo $?
}

configure_with one.c
make $MAKE_ARGS
test "$(status)" = "1"

sleep 2
configure_with two.c
make $MAKE_ARGS
test "$(status)" = "2"

sleep 2
configure_with one.c
make $MAKE_ARGS
test "$(status)" = "1"

# Having caught up, the build settles rather than redoing it each time.
make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log
