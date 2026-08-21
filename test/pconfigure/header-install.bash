#include "harness_start.bash"

mkdir -p include

##############################################################################
# A header is installed as the header it is                                  #
##############################################################################
# A HEADERS with nothing under it is installed rather than built, and
# installing it means putting the file where it goes.  This used to
# run it through pbashc, which is the compiler for bash scripts: it
# put a "#!/bin/bash" on the front of every installed C header and
# took out every "#include" line, because an "#include" is a directive
# to pbashc rather than a line of the file it is reading.
#
# What came out still looked like a header and still installed
# without complaint, which is why it lasted.  It only stops being a
# header at the point somebody compiles against it and finds the
# declarations it was supposed to pull in aren't there.
cat >Configfile <<EOF
LANGUAGES += c

HEADERS   += test.h
EOF

# Two things pbashc would have taken out, and one it would have put
# in.  The include is written the angled way on purpose: that is the
# spelling a C header uses for the headers it needs, and it is the one
# that used to disappear.
cat >include/test.h <<EOF
  #include <stdio.h>
  #include <stdlib.h>

int test_one(FILE *f);
int test_two(size_t n);
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# phc is what installs a header, and it is what the explicit "h"
# language has always used.  Naming the program in the assertion
# rather than just checking the output is worth it: the two programs
# agree on every header that has no directives in it, so a test that
# only compared contents would go on passing if this were put back.
grep -q "^	@.*phc -i include/test.h -o " Makefile
if grep -q "pbashc -i include/test.h" Makefile
then
    exit 1
fi

make $MAKE_ARGS DESTDIR=$(pwd)/install install

# Byte for byte.  A header is not a thing with a format anybody here
# understands, so the only correct transformation of one is none.
diff -u include/test.h install/usr/local/include/test.h

# And the two halves of that spelled out, so a failure says which way
# it went wrong rather than just printing a diff.
grep -q "#include <stdio.h>" install/usr/local/include/test.h
grep -q "#include <stdlib.h>" install/usr/local/include/test.h
if head -1 install/usr/local/include/test.h | grep -q "^#!"
then
    exit 1
fi

exit 0
