#include "harness_start.bash"

# "--configure NAME=VALUE" splits at the first '=', so a string option
# whose value itself holds one -- a kernel command line is mostly '='
# signs -- keeps all of them in the value and the name stays the name.
# The quotes round a string value say it's a string, so it's set with
# --set-str and without them; that includes the empty string, which is
# a value a string option can have and has to arrive as one empty
# argument rather than none.  The fake scripts/config writes down what
# it was handed, one argument per line, so the build shows what the
# tree's own program would have seen.
mkdir -p sub/scripts

cat >sub/Kconfig <<'EOF'
config CMDLINE
	string "cmdline"
config LOCALVERSION
	string "localversion"
EOF

cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build
all:
	@mkdir -p $(O)
defconfig olddefconfig:
	@mkdir -p $(O)
	@touch $(O)/.config
EOF

cat >sub/scripts/config <<EOF
#!/bin/sh
for arg in "\$@"
do
    echo "[\$arg]"
done >>$(pwd)/config-args
EOF
chmod +x sub/scripts/config

cat >Configfile <<'EOF'
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += sub
CONFIGUREOPTS += --configure CONFIG_CMDLINE="console=ttyS0 root=/dev/vda"
CONFIGUREOPTS += --configure CONFIG_LOCALVERSION=""
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat config-args

# One call per option, each "--file <.config> --set-str NAME VALUE":
# five arguments, so ten lines in all.  A value split at its space or
# a second '=' would add lines and a dropped empty value would take
# one away, so the count is checked as well as what follows each
# --set-str.
test "$(grep -c -- '^\[--set-str\]$' config-args)" = "2"
test "$(wc -l <config-args | tr -d ' ')" = "10"
grep -A2 -- '^\[--set-str\]$' config-args | grep -v '^--$' >set-str-args
cat >expected-set-str-args <<'EOF'
[--set-str]
[CONFIG_CMDLINE]
[console=ttyS0 root=/dev/vda]
[--set-str]
[CONFIG_LOCALVERSION]
[]
EOF
diff -u expected-set-str-args set-str-args

exit 0
