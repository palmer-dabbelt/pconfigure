#include "harness_start.bash"

# "-DNAME=value" defines NAME, which is what a compiler would say and
# what pbashc's "#ifndef" already said.  Its "#ifdef" compared the
# whole of "NAME=value" against the name instead, so the one define
# made "#ifdef NAME" and "#ifndef NAME" both false, and a script lost
# whatever it only wanted when the name was given a value.
#
# A longer name that starts with the defined one is still a different
# name, which is the mistake the "#ifndef" comparison made the other
# way around.
#
# pbashc's conditionals only decide which "#include"s are expanded --
# every other line is a comment to bash and goes out as it came in --
# so each branch here is an include of a file that says which one it
# is.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -DFANCY=yes
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef FANCY
#include "ifdef.bash"
#endif
#ifndef FANCY
#include "ifndef.bash"
#endif
#ifdef FANCYX
#include "longer.bash"
#endif
#ifndef FANCYX
#include "not-longer.bash"
#endif
echo tool
EOF

for name in ifdef ifndef longer not-longer
do
    echo "echo $name" >src/$name.bash
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "ifdef
not-longer
tool"

exit 0
