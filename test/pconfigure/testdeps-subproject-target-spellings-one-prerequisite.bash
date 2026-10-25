#include "harness_start.bash"

# A TESTDEPS on a vendored tree's named output can be spelled from the
# project ("obj/sub/build/...") or from the tree's name ("sub/build/..."),
# and either way with the stray "./" and "//" a hand-written path picks
# up.  Every one of those has to come out as the one path the output's
# rule is written under, or the test waits on a file nothing builds.
mkdir -p sub/configs test/integration

cat >sub/Kconfig <<'EOF'
config BASE
	bool "base"
	default y
EOF

echo CONFIG_BASE=y > sub/configs/tiny_defconfig

cat >sub/Makefile <<'EOF'
O ?= $(CURDIR)/build
all: $(O)/.config
	@mkdir -p $(O)/d
	@echo x > $(O)/d/f
tiny_defconfig:
	@mkdir -p $(O)
	@cp $(CURDIR)/configs/tiny_defconfig $(O)/.config
EOF

echo 'exit 0' > test/integration/boots.bash

for spelling in ./obj/sub/build/d/f obj//sub/build/d/f sub/build/./d/f \
                sub//build/d/f ./sub/build/d/f
do
    rm -rf obj check Makefile

    cat >Configfile <<EOF
BUILD_SYSTEMS      += kconfig
SUBPROJECTS        += sub
CONFIGUREOPTS      += --defconfig tiny_defconfig
SUBPROJECT_TARGETS += d/f

LANGUAGES          += bash
PHONY              += integration
TESTDEPS           += $spelling
TESTSRC            += boots.bash
EOF

    $PTEST_BINARY $PCONFIGURE_ARGS
    grep -q "^check/integration/boots.bash: .* obj/sub/build/d/f$" Makefile

    # Asking for the result alone builds the tree first.
    make $MAKE_ARGS check/integration/boots.bash
    test -f obj/sub/build/d/f
done

exit 0
