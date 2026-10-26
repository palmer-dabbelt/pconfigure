#include "harness_start.bash"

# COMPILER is part of what an object's name is hashed from, which is
# why switching compilers recompiles.  Switching back named the object
# the first compiler left behind, and the binary the second one linked
# used to stay.  This makes sure it is relinked: the two wrappers here
# differ only in a -D they add, so the program says which compiler it
# was built by.

mkdir -p src

for n in 1 2
do
    cat >cc$n <<EOS
#!/bin/bash
exec cc -DVAL=$n "\$@"
EOS
    chmod +x cc$n
done

cat >src/main.c <<'EOS'
#include <stdio.h>
int main(void) { printf("%d\n", VAL); return 0; }
EOS

configure_with() {
    cat >Configfile <<EOC
LANGUAGES   += c
COMPILER     = $(pwd)/cc$1
BINARIES    += app
SOURCES     += main.c
EOC
    $PTEST_BINARY $PCONFIGURE_ARGS
}

configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
configure_with 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"

sleep 2
configure_with 1
make $MAKE_ARGS
test "$(./bin/app)" = "1"
