# pconfigure — Known Issues

A record of a multi-round adversarial security review of pconfigure's new
autotools/CMake/cargo/kconfig/buildroot support (the work that lets pconfigure
drive Verilator, `sw/llvm-project`, and wavetools natively instead of through
CISC-V's `Makefile.tools`). Each round fixed a named list of escapes; each
round's own adversarial confirmers then found the next instance of the same
shape, which is why this took seven rounds. Round 7 fixed the two shared
chokepoints the escapes kept routing around and closed the highest-severity
items still open; further escape-hunting was deliberately stopped there —
see "Why we stopped" below.

## Fixed across rounds 1–7

- **The core injection gap** (round 7): the two places every Configfile-written
  path and build-system option name is supposed to funnel through —
  `checked_project_path()` (`src/libpconfigure/build_system.c++`) and
  `leaves_the_project()` / the new `refuse_unsafe_metacharacter()` helper
  (`src/libpconfigure/command_processor.c++`) — checked for `/`, `..`, `$`, and
  space, but never `;`, so `LIBDIR = lib;>/abs/PWNED;true` (and the same shape
  via `ENTITLEMENTS`, `TESTDEPS`, `SOURCES`, `SRCDIR`, `SUBPROJECTS`,
  `DEPTESTS`, `GENERATE`, `PREFIX`) ran an arbitrary command on a plain `make`
  with no diagnostic. Fixed with a single shared `build_system::
  unsafe_metacharacter()` check (`;&|`()<>` and newline) called from both
  chokepoints, and wired onto all nine commands above (six of which had no
  path check of any kind before this round).
- **cmake `-U` glob-pattern bypass**: `-UCMAKE_INSTALL_P*` matched the literal
  name `CMAKE_INSTALL_PREFIX` as a shell/cmake glob rather than as text, so a
  refused variable name could be un-set again by a pattern that never spells
  it out. Fixed by refusing glob metacharacters (`*?[`) in the name half of
  any `-U`/`-D`-style argument outright, verified against real cmake 4.4.3.
- **bash brace-expansion bypass**: `-DCMAKE_INSTALL_PRE{F,F}IX=...` is
  brace-expanded by bash (`SHELL=/bin/bash` in generated recipes, per
  `src/libmakefile/makefile.c++`) before cmake ever sees it, so a check that
  scans the written text for the variable name never saw it. Fixed by
  refusing `{}` (and `` ` `` for command substitution) in the same name half,
  verified against real cmake 4.4.3.
- **kbuild `M=` / `KBUILD_EXTMOD=`**: kconfig's "must stay inside the object
  directory" list had `O`/`KBUILD_OUTPUT` but not the external-module
  variable or its environment spelling. Fixed by adding both to
  `build_system_kconfig::already_answered()`.
- **autoconf `--cache-file=PATH`**: wrote/overwrote an arbitrary file with no
  check. Fixed by adding `cache-file`/`cache_file` to autotools'
  `already_answered()`, verified against real autoconf 2.73.
- **buildroot `--external`**: resolved via its own unchecked `realpath()`
  instead of going through `checked_project_path()`; also missing
  `PER_PACKAGE_DIR` from its destination list. Both fixed.
- **kconfig `KCONFIG_CONFIG`**: missing from the destination list, letting
  `--make-var`/`--env` redirect where the merged `.config` is written. Fixed.
- Full history of rounds 1–6 (the original DESTDIR/install-prefix escapes,
  the whitelist-over-blacklist redesign, `CMAKE_STAGING_PREFIX`, cargo's
  `reserved_flag()`/`reserved_variable()` closures, and the earlier build/API
  work adding CMake, autotools, cargo, and buildroot support in the first
  place) is not repeated here — see git history for
  `tools/pconfigure/src/libpconfigure/build_systems/`.

All fixes are pinned by tests (`test/pconfigure/configfile-metacharacters.bash`,
`configfile-path-escapes.bash`, `autotools.bash`, `cmake.bash`, `cargo.bash`,
`kconfig-opts.bash`, `buildroot.bash`, `subprojects-in-objdir.bash`,
`distclean-quoting.bash`) and were each proven by reverting the specific fix,
rebuilding from clean, confirming the test fails (read via
`tar -xOf check/pconfigure/<test>.bash ptest__return`, not `make`'s exit
status — `make check` always exits 0 regardless of pass/fail), then restoring
byte-identically and confirming it passes again.

## Residual risk — deliberately not fixed

These are real, but each is either a fundamental limit of lexical checking, a
generalization of "any tool has flags/goals with file-system side effects"
that has no finite list to enumerate, or outside pconfigure's reach entirely.
Fixing them piecemeal is exactly the whack-a-mole rounds 1–7 converged on
stopping.

- **kconfig `--target modules_install`**: a legitimate kbuild goal that
  installs kernel modules to `/lib/modules` and `/boot` by kbuild's own
  built-in defaults, needing no `INSTALL_MOD_PATH`/`INSTALL_PATH` to trigger
  it. Quoting the target name (already done) stops injection but not a
  legitimate goal with a real side effect; refusing specific goal names is
  open-ended (kbuild has dozens).
- **cmake `--graphviz=`, `--trace-redirect=`, `--profiling-output=`**:
  diagnostic/tooling flags that write a file at an arbitrary path, riding
  along through the generic `--configure-arg` passthrough like any other
  cmake flag. The same "any tool has flags that write files" problem
  generalizes to every build system's raw-argument escape hatch
  (`--configure-arg`, `--make-var`, cargo's `--arg`) — enumerating every
  tool's flags was rejected as unbounded.
- **Lexical-only path containment**: every containment check in this codebase
  (`file_utils::inside()`, used by `checked_install_dir()` and the
  SUBPROJECTS-in-objdir and `cache_clean_target()` checks) compares path
  *text*, not resolved filesystem identity. A symlink placed inside an object
  directory can make the written name and the resolved destination disagree.
  This is in tension with a deliberate round-4 design choice (a path that
  stays textually inside the project names the same directory regardless of
  where pconfigure is invoked from) and was left undecided rather than
  accidentally missed.
- **Shell-metacharacter names on disk**: a project/source directory or file
  name containing an apostrophe, space, or shell metacharacter does not
  build — the compile/link recipes (`src/libpconfigure/languages/cxx.c++`,
  `languages/bash.c++`) paste such names into Makefile recipes as raw text.
  Pre-existing, pconfigure-wide, not a regression from this work.
- **Ambient shell environment at build time**: a developer's exported
  `CARGO_BUILD_TARGET`, `MAKEFLAGS`, etc. before running `make` can redirect a
  build the same way a Configfile-written `--env` could. The Configfile
  channel is now checked; the shell's own environment at the moment `make`
  runs is outside pconfigure's reach without removing the ability to inherit
  environment at all.
- **cargo's deny-lists aren't hoisted onto the shared chokepoint**: cargo
  keeps its own `reserved_flag()`/`reserved_variable()` checks
  (`src/libpconfigure/build_systems/cargo.c++`) instead of routing through
  `build_system::refuse_second_answer()`. This is a deliberate design
  decision (documented in `build_system.h++`), not an oversight: cargo's
  `answers` struct describes a different (`NAME=VALUE`) grammar than the
  other four build systems share.

## Why we stopped

This threat model is a single-author project (see the top-level `CLAUDE.md`):
Configfiles are code the author writes and checks into git, not adversarial
input from an untrusted party. The chokepoint fix in round 7 closes the
class of bug that mattered most — a typo or copy-paste mistake in a
Configfile silently running an unintended command — and the residual items
above all require either an author deliberately attacking their own build
(symlink tricks, ambient environment) or accepting that a generic
passthrough flag is generic. Continuing to round 8+ to enumerate the next
tool flag or goal name was judged not worth it.
