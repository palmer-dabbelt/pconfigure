#include "harness_start.bash"

cat >Configfile <<EOF
LANGUAGES += c
BINARIES += test
SOURCES += test.c
EOF

mkdir src
cat >src/test.c <<EOF
  #include <stdio.h>
int main() {
  #ifdef DEFINE1
  printf("define1\n");
  #endif
  #ifdef DEFINE2
  printf("define2\n");
  #endif
  return 0;
}
EOF

cat >test.gold <<EOF
define1
EOF

MAKE_ARGS="CFLAGS=\"-DDEFINE1=1\""

#include "harness_end.bash"
