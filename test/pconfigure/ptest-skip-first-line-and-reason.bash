#include "harness_start.bash"

# A test that says SKIP more than once has its first reason reported,
# since that is the one that stopped it and the rest are usually the
# same sentence repeated by a helper.  The reason is printed after the
# one space the convention puts after the colon, and a reason written
# without that space is printed whole rather than losing a letter.
# Either output stream will do; both are captured into one place.

ptest="$(dirname "$PTEST_BINARY")/ptest"

run() {
    local name="$1"
    mkdir -p "$name"
    cat >"$name.sh"
    chmod +x "$name.sh"
    "$ptest" --test "$name.sh" --out "$name/t"
}

run twice <<'EOF'
#!/bin/bash
echo "SKIP: no qemu-system-riscv64" >&2
echo "SKIP: no qemu-system-aarch64"
exit 0
EOF
"$ptest" --no-check-make-check --check-dir twice > twice.out
cat twice.out
grep -q "^- SKIP	t	no qemu-system-riscv64$" twice.out
if grep -q "aarch64" twice.out
then
    exit 1
fi

run tight <<'EOF'
#!/bin/bash
echo "SKIP:no kvm"
exit 0
EOF
"$ptest" --no-check-make-check --check-dir tight > tight.out
cat tight.out
grep -q "^- SKIP	t	no kvm$" tight.out

exit 0
