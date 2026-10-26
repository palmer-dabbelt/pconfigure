verbose="false"
quiet="false"
check_make_check="true"
abrt_is_fail="false"
check_dirs=()
abrt_dirs=()
check_suite=""
check_named="false"
check_results=()

# Whether something that knows the build has said where its results
# are, even if the answer was "nowhere": a build of nothing but
# subprojects that build nothing has no check directory at all, and
# "check" is then just a directory somebody might have made.
check_dirs_known="false"

# A directory is the same directory with a slash after it -- which is
# how a shell's tab completion hands one over -- but the report finds
# which directory a result named outright belongs to by comparing the
# text, and "check/" followed by "/*" matches nothing.  So the slashes
# come off once, here, and everything after this sees one spelling.
# "/" alone keeps its slash, since without it there is no directory.
strip_slashes() {
    local dir="$1"
    while [[ "$dir" == */ ]] && [[ "$dir" != "/" ]]
    do
        dir="${dir%/}"
    done
    echo "$dir"
}

while [[ "$1" == --* ]]
do
    if [[ "$1" == "--verbose" ]]
    then
        verbose="true"
    elif [[ "$1" == "--quiet" ]]
    then
        quiet="true"
    elif [[ "$1" == "--no-check-make-check" ]]
    then
        check_make_check="false"
    elif [[ "$1" == "--abrt-is-fail" ]]
    then
        # A test that calls abort() (an assert(), an uncaught C++
        # exception reaching the default terminate handler, and so
        # on) exits 134 -- 128+SIGABRT -- which is otherwise scored as
        # an EROR: see the classification loop below for why that's
        # the right default and what this flag deliberately narrows.
        abrt_is_fail="true"
    elif [[ "$1" == "--abrt-is-fail-dir" ]]
    then
        # A --check-dir whose project asked for --abrt-is-fail, and
        # --abrt-is-fail for that directory's results alone.  One
        # report covers every project a build pulled in, and whether
        # a SIGABRT is a FAIL is each project's own answer: a parent
        # that never asked shouldn't have its crashes rescored by a
        # child that did, and a child that asked shouldn't lose that
        # just because the report was run from above it.
        shift
        dir="$(strip_slashes "$1")"
        check_dirs+=("$dir")
        abrt_dirs+=("$dir")
    elif [[ "$1" == "--no-check-dirs" ]]
    then
        # What a Makefile says in place of any --check-dir when no
        # project it covers has a check directory.
        check_dirs_known="true"
    elif [[ "$1" == "--check-dir" ]]
    then
        # One per project: a build with subprojects has its test
        # results spread across all of them.
        shift
        check_dirs+=("$(strip_slashes "$1")")
    elif [[ "$1" == "--check-suite" ]]
    then
        # Reports one named set of tests rather than everything that
        # has been run.  Which tests are in a suite is something the
        # build was told and this was handed: a directory of tarballs
        # says nothing about which of them belong together.
        shift
        check_suite="$1"
        check_named="true"
    elif [[ "$1" == "--check-named" ]]
    then
        # Reports exactly the results named with --check-result, and
        # none if none were, the way a suite does -- for the report of
        # everything "make check" runs.  A directory of tarballs holds
        # the last result of every test that was ever run in it,
        # including the ones a Configfile has since stopped naming, and
        # one of those that failed would otherwise keep that report red
        # for good about a test that no longer exists.  Without it a
        # run reads the directories, which is still the right answer
        # for somebody typing "ptest": they asked what is on disk.
        check_named="true"
    elif [[ "$1" == "--check-result" ]]
    then
        # One test of that set, named outright.
        shift
        check_results+=("$1")
    else
        break
    fi
    shift
done

if [[ "${#check_dirs[@]}" == "0" ]] && [[ "$check_dirs_known" == "false" ]]
then
    # A build with subprojects has its test results spread across all
    # of them, and there's nothing in this directory that says where
    # the others are -- so pconfigure writes the list down next to the
    # Makefile it writes at the same time.  A Makefile old enough not
    # to have one, or a tree that was never configured, still has the
    # one directory everybody has.
    if [[ -r obj/check-dirs ]]
    then
        # And an empty list is an answer too, not a missing one.
        check_dirs_known="true"

        # A tab and "abrt-is-fail" after a directory is the same thing
        # --abrt-is-fail-dir says on the command line.
        while IFS=$'\t' read -r dir flag
        do
            dir="$(strip_slashes "$dir")"
            if [[ "$dir" != "" ]]
            then
                check_dirs+=("$dir")
                if [[ "$flag" == "abrt-is-fail" ]]
                then
                    abrt_dirs+=("$dir")
                fi
            fi
        done <obj/check-dirs
    fi
fi

if [[ "${#check_dirs[@]}" == "0" ]] && [[ "$check_dirs_known" == "false" ]]
then
    check_dirs=(check)
fi

# The stamp "make check" builds here, which is what says whether the
# results being reported are current.  A project that has told make
# which suite "make check" means builds that suite's stamp and never
# touches the one everything else builds, so asking about the wrong
# one would warn that the build is stale every single time.
check_stamp="obj/check-all-done"
if [[ -r obj/check-stamp ]]
then
    while read -r line
    do
        if [[ "$line" != "" ]]
        then
            check_stamp="$line"
        fi
    done <obj/check-stamp
fi

if [[ "$1" == "--check" ]]
then
    make check
    shift
fi

if [[ "$1" == "" ]]
then
    if [[ "$check_make_check" == "true" ]]
    then
        if ! make -q "$check_stamp" 2>/dev/null
        then
            echo "*** WARNING: 'make check' is not up to date ***"
            echo ""
            echo ""
            echo ""
        fi
    fi

    # If there's no test directory anywhere then just give up
    existing=()
    for dir in "${check_dirs[@]}"
    do
        if test -d "$dir"
        then
            existing+=("$dir")
        fi
    done

    # A suite that nobody joined has nothing to say, and says the same
    # true thing in the same words as a tree that was never tested.
    if [[ "$check_named" != "true" ]]
    then
        found="${#existing[@]}"
    else
        found="${#check_results[@]}"
    fi

    if [[ "$found" == "0" ]]
    then
        echo "No tests"
        exit 0
    fi

    # Names a test by the project it belongs to, so that two projects
    # with a test of the same name stay tellable apart.
    label() {
        local dir="$1"
        local file="$2"
        local rest="${file#$dir/}"
        local project="$(dirname "$dir")"

        if [[ "$project" == "." ]]
        then
            printf '%s\n' "$rest"
        else
            printf '%s\n' "$project/$rest"
        fi
    }

    # Which check directory a result named outright was found under,
    # which is what a whole run gets for free by walking down from the
    # directory itself.  The longest one that matches, so that a
    # project nested inside another is named as itself.  The search
    # starts from nothing rather than from ".", the answer for a result
    # under none of them, because "." is one character long and a
    # directory whose name is too could never beat it.
    result_dir() {
        local file="$1"
        local out=""
        local dir

        for dir in "${check_dirs[@]}"
        do
            if [[ "$file" == "$dir"/* ]] && [[ "${#dir}" -gt "${#out}" ]]
            then
                out="$dir"
            fi
        done

        echo "${out:-.}"
    }

    # The results this run is reporting on, each with the directory it
    # belongs to.  A run that was handed its results -- a suite, or the
    # whole of what "make check" runs -- is exactly the results it was
    # named, since a tarball on disk carries no record of which suites
    # ran the test that left it, nor of whether any Configfile still
    # names that test.  Otherwise it is everything in those
    # directories.
    results() {
        if [[ "$check_named" == "true" ]]
        then
            local f
            for f in "${check_results[@]}"
            do
                printf '%s\t%s\n' "$(result_dir "$f")" "$f"
            done | sort -k 2
            return
        fi

        local dir
        for dir in "${existing[@]}"
        do
            # Taken a whole line at a time and as written: a plain
            # read eats the backslashes out of a name like
            # "C:\cygwin", and the result it then names does not
            # exist, so a test that passed would be scored an EROR.
            find "$dir" -type f | sort | while IFS= read -r f
            do
                printf '%s\t%s\n' "$dir" "$f"
            done
        done
    }

    # Whether a SIGABRT under this check directory is scored as a FAIL.
    dir_abrt_is_fail() {
        local d
        if [[ "$abrt_is_fail" == "true" ]]
        then
            return 0
        fi
        for d in "${abrt_dirs[@]}"
        do
            if [[ "$d" == "$1" ]]
            then
                return 0
            fi
        done
        return 1
    }

    # This subshell is necessary to keep these variables after the
    # loop terminates
    results | {
        run="0"
        pass="0"
        skip="0"
        fail="0"
        error="0"

        # Split only at the tab results() put there, and with
        # backslashes left alone, for the same reason as above.
        while IFS=$'\t' read -r dir f
        do
            run=$(expr $run + 1)
            name="$(label "$dir" "$f")"

            # This is a special case that's used for printing the
            # success/failure of test cases
            ret="$(tar -xOf "$f" ptest__return)"
            if [[ "$ret" == "0" ]]
            then
                # A test that decided it could not run says so and
                # exits 0, because nothing is wrong with the tree and
                # a FAIL would be a lie about it.  Counted as a pass
                # -- which is what happened for as long as nobody
                # looked -- that makes "ran and succeeded" and "did
                # not run" the same number, and the second is the one
                # that goes wrong silently: a missing cross compiler
                # or an empty generated payload takes a third of a
                # suite out of service and the report still says
                # everything passed.
                #
                # So the report asks, and the exit status stays what
                # it always was: every result already on disk keeps
                # meaning exactly what it meant, which is the whole
                # difference between this and reserving a third status
                # for a skip.
                #
                # The convention is a line of its own beginning with
                # "SKIP:", which is what the suites here already write
                # -- to stderr, which lands in the same captured file
                # as stdout.  A line and not a substring: a test is
                # free to mention the word in passing, and reading
                # that as a verdict would be the same wrong answer
                # pointing the other way.  Anywhere in the output and
                # not just the first line, because a test that got
                # half way through before finding out it could not
                # finish has still not run.
                #
                # Read as text whatever is in it.  The output is
                # whatever the test and the tools it ran printed,
                # which for a compiler or an emulator is often not
                # text at all, and one NUL byte is enough for grep to
                # call the whole stream binary: it then says on stderr
                # that a binary file matched and prints no line, so
                # the skip would be counted as a pass and the report
                # would carry grep's message in the middle of it.
                why="$(tar -xOf "$f" ptest__output 2>/dev/null \
                       | grep -a -m 1 '^SKIP:')"
                if [[ "$why" != "" ]]
                then
                    # The reason, which was otherwise reachable only
                    # by opening the tarball by hand.  The report has
                    # the line in front of it already, so saying it
                    # costs nothing.  Quiet mode stays quiet: it
                    # prints a line per test only for the ones
                    # somebody has to act on, and the count below is
                    # how a suite that stopped running half of itself
                    # shows up there instead.
                    if [[ "$quiet" != "true" ]]
                    then
                        # Both the name and the reason are text
                        # the test chose, so they go out through
                        # printf's "%s" and not through echo -e:
                        # as escapes, a "\c" in a path like
                        # "C:\cygwin" would end the line without its
                        # newline and glue the next test's verdict
                        # onto it, and a "\t" or "\n" would add a
                        # column or a line that is no test's.
                        why="${why#SKIP:}"
                        printf -- '- SKIP\t%s\t%s\n' "$name" "${why# }"
                    fi
                    skip=$(expr $skip + 1)
                else
                    if [[ "$quiet" != "true" ]]
                    then
                        printf '  PASS\t%s\n' "$name"
                    fi
                    pass=$(expr $pass + 1)
                fi
            elif [[ "$ret" == "1" ]]
            then
                printf '* FAIL\t%s\n' "$name"
                fail=$(expr $fail + 1)

                # What somebody asking for --verbose wants is what
                # the test printed.  The result is a tarball that
                # also holds the return code and whatever else the
                # test left in its scratch directory, so printing the
                # file itself buries that output in tar headers, other
                # files and NUL padding: pull out just the output, the
                # same way an EROR below does.
                if [[ "$verbose" == "true" ]]
                then
                    tar -xOf "$f" ptest__output
                fi
            elif [[ "$ret" == "134" ]] && dir_abrt_is_fail "$dir"
            then
                printf '* FAIL\t%s\n' "$name"
                fail=$(expr $fail + 1)

                if [[ "$verbose" == "true" ]]
                then
                    tar -xOf "$f" ptest__output
                fi
            else
                printf '! EROR\t%s\n' "$name"
                error=$(expr $error + 1)

                if [[ "$verbose" == "true" ]]
                then
                    tar -xOf "$f" ptest__output
                fi
            fi
        done

        if [[ "$quiet" == "true" ]]
        then
            # Printed only when there is one, the way NFAIL and NEROR
            # are: the quiet report of a green run is an empty file,
            # and that is load-bearing -- "make check" writes it and
            # stale-report.bash asserts its size.  A suite with
            # nothing to excuse keeps saying nothing.
            if [[ "$skip" != "0" ]]
            then
                echo -e "NSKIP\t"$skip
            fi
            if [[ "$fail" != "0" ]]
            then
                echo -e "NFAIL\t"$fail
            fi
            if [[ "$error" != "0" ]]
            then
                echo -e "NEROR\t"$error
            fi
        else
            echo ""
            echo -e "NRUN\t"$run
            echo -e "NPASS\t"$pass
            echo -e "NSKIP\t"$skip
            echo -e "NFAIL\t"$fail
            echo -e "NEROR\t"$error
        fi

        if [[ "$fail" != "0" ]]
        then
            exit 1
        fi

        if [[ "$error" != "0" ]]
        then
            exit 2
        fi
    }

    error="$?"

    if [[ "$check_make_check" == "true" ]]
    then
        if ! make -q "$check_stamp" 2>/dev/null
        then
            echo ""
            echo ""
            echo ""
            echo "*** WARNING: 'make check' is not up to date ***"
        fi
    fi

    exit $error
fi

# Parse the commandline arguments
test=""
out=""
bin=""
srcdir=""
checkdir=""
scratchdir=""
command=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--test" ]]
    then
        test="$2"
        shift
        shift
    elif [[ "$1" == "--out" ]]
    then
        out="$2"
        shift
        shift
    elif [[ "$1" == "--bin" ]]
    then
        bin="$2"
        shift
        shift
    elif [[ "$1" == "--srcdir" ]]
    then
        srcdir="$2"
        shift
        shift
    elif [[ "$1" == "--checkdir" ]]
    then
        checkdir="$2"
        shift
        shift
    elif [[ "$1" == "--scratchdir" ]]
    then
        scratchdir="$2"
        shift
        shift
    elif [[ "$1" == "--args" ]]
    then
        shift
        break
    else
        echo "Unknown argument: $1"
        exit 1
    fi
done

# The line of a check rule that runs this starts with a "+", which is
# how make knows to hand a test its jobserver: a test that runs a make
# of its own then shares the outer "-j" rather than either running
# serially or multiplying it.  But "+" also tells make that the line is
# a recursive make, and make runs those even under "-n", "-t" and "-q"
# -- they're how a dry run of a sub-make finds out what the sub-make
# would do.  A test is not that.  It's the most expensive thing a build
# runs and the one most likely to reach outside the tree, and a dry run
# that starts it, and then writes a result saying it's done, is the
# opposite of what was asked for.
#
# So this is the half of the "+" that make can't do: make has already
# printed this command for a "-n" and will touch the result itself for
# a "-t", and all that's left is not to run.  Splitting the decision
# into the Makefile instead -- a "+" that only some expansions of the
# line carry -- does stop the test, but make only clears a line to
# share its jobserver by the "+" it sees before expanding anything, so
# that loses the very thing the "+" is there for.
#
# The modes are single letters bunched together at the very start of
# $MAKEFLAGS -- "n", or "ns" for "make -s -n" -- which GNU make writes
# with no dash in front.  When there are none, make starts $MAKEFLAGS
# with a space instead, and whatever follows is an option of its own:
# " -Iinclude", " -Otarget", " -j2 --jobserver-auth=...", or the " --"
# before a variable set on the command line.  Those are full of "n"s
# and "t"s that are only letters of a directory name or an argument,
# so the match is against $MAKEFLAGS exactly as make wrote it, with
# neither the leading space stripped nor a dash allowed: taking
# "make -I include check" for a dry run would skip every test and
# report a clean check without having run one.
#
# $MAKELEVEL is how this knows make put them there: a ptest run by
# hand from a shell with some MAKEFLAGS of its own exported is not a
# dry run of anything.
if [[ "$MAKELEVEL" != "" && "$MAKEFLAGS" =~ ^[[:alpha:]]*[ntq][[:alpha:]]*( |$) ]]
then
    exit 0
fi

abs_path() {
    case "$1" in
        /*) echo "$1" ;;
        *)  echo "$(pwd)/$1" ;;
    esac
}

out="$(abs_path "$out")"
test="$(abs_path "$test")"

# A test that isn't testing any one program -- one written under a
# PHONY -- gets handed no "--bin" at all.  Making that absolute would
# turn nothing into the directory ptest was started in, which is a
# path, exists, and is not a program: a test that reached for it would
# get something rather than noticing there was nothing.
if [[ "$bin" != "" ]]
then
    bin="$(abs_path "$bin")"
fi

# What pconfigure writes here is already absolute -- make worked it
# out, since only make knows what directory it was run in.  The guard
# is for a ptest run by hand, which was told nothing and should say
# nothing rather than name whatever directory it started in.
if [[ "$srcdir" != "" ]]
then
    srcdir="$(abs_path "$srcdir")"
fi

# The directory this test's own result lands in, which is where the
# result of every other test of the same target lands too -- so it's
# how one test finds what another one left behind.  Same guard, same
# reason: a ptest run by hand was told nothing and says nothing.
if [[ "$checkdir" != "" ]]
then
    checkdir="$(abs_path "$checkdir")"
fi

# Where a test puts what it does NOT want collected.  $PTEST_TMPDIR is
# the system temp, it is emptied for every run, and every byte left in
# it is tarred into the result -- which is the right answer for logs and
# the wrong one for a multi-gigabyte disk image.  Three separate ways:
# the tar costs as much as the test, the result is a copy of something
# that already exists, and the system temp is usually a different volume
# from the tree, so the copy-on-write clone that made building the image
# cheap does not survive being handed through it.
#
# So this one is inside the project, next to the test's own compiled
# self, and none of those three things happen to it.  What it costs
# instead is that it is NOT emptied between runs and NOT removed when
# the test finishes: a fixture too expensive to tar is usually too
# expensive to rebuild, and reuse across runs is the whole point.  A
# test that wants it clean is the one that knows that, and clears it
# itself.
#
# Same guard as the two above, and the same reason: a ptest run by hand
# was told nothing, and a test asking for scratch it was never given
# should see nothing rather than write into whatever directory the run
# started in.
if [[ "$scratchdir" != "" ]]
then
    scratchdir="$(abs_path "$scratchdir")"
    mkdir -p "$scratchdir"
fi

# This is the regular path where we actually run a test case.
#
# Where mktemp puts this is up to $TMPDIR, which is the user's to set
# and can have a space in it like any other path, so every use of it
# below is quoted.  The trap most of all: written with the path pasted
# in when the trap is set, a "/home/me/my tmp" became an "rm -rf" of
# "/home/me/my" and of a relative "tmp/..." -- neither of which is the
# directory this made, and the first of which is somebody's.  Single
# quotes leave the expansion to when the trap runs, where it is quoted.
#
# Removing it has to cope with whatever the test left there, and that
# includes directories nobody can write to: Go's module cache, a git
# object store, a tarball unpacked with the modes it recorded.  A plain
# "rm -rf" can't empty those, so it fails and the directory stays in
# the system temp for good.  Giving ourselves permission back first is
# enough -- this is our directory, made by the mktemp above, so nothing
# in it belongs to anybody else.  Read and search as well as write,
# because a directory chmod can't look into is one it can't fix either.
tmpdir=`mktemp -d -t ptest-wrapper.XXXXXXXXXX`
remove_tmpdir() {
    if test -d "$tmpdir"
    then
        chmod -R u+rwX "$tmpdir" 2>/dev/null
        rm -rf "$tmpdir"
    fi
}
trap 'remove_tmpdir' EXIT

# A test that builds anything runs a make of its own, and it must not
# inherit this one's flags.  make puts them in the environment of every
# recipe it runs, so a "make -B" out here arrives in there as an order
# to rebuild everything -- which is the one thing the tests that check
# what gets rebuilt are looking at, and they fail for a reason that has
# nothing to do with what they test.  "-n" and "-k" are no better.
# Nothing about the outer make's command line means anything to a test.
unset MAKEFLAGS
unset MFLAGS
unset MAKELEVEL

export PTEST_BINARY="$bin"
export PTEST_SRCDIR="$srcdir"
export PTEST_CHECKDIR="$checkdir"
export PTEST_TMPDIR="$tmpdir"
export PTEST_SCRATCH_DIR="$scratchdir"

# The output is captured so a result is the same whoever produced it,
# and the input has to be pinned down for the same reason.  Left
# attached, a test that reads stdin gets the terminal of whoever typed
# "make check" (and hangs until a key is pressed), or the rest of the
# list of a script that runs "make check" from a "while read" loop (and
# that loop quietly stops after one entry).  A test is given nothing.
"$test" "$@" </dev/null >&"$tmpdir"/ptest__output
status="$?"

# The directory is the test's to do what it likes with until it exits,
# and taking permissions away is one of the things a test does on
# purpose: "chmod a-w" on the one directory it owns is how it checks
# that a program refuses to write somewhere it can't.  Everything after
# this point is ptest's, though -- the status is written into that
# directory, the cd goes into it and tar reads every file in it -- so
# the permissions come back now, the same way and for the same reason
# as they do before removing it.  Left until the removal, a read-only
# directory had no room for the status and a test that passed was
# scored as an EROR, one at mode 000 couldn't be entered and failed
# the check target outright, and an unreadable file was dropped from
# the result with tar's complaint printed in the middle of make's
# output.  This is what the test left, not how it left it: the modes
# in the result are the restored ones.
chmod -R u+rwX "$tmpdir" 2>/dev/null
echo "$status" >"$tmpdir"/ptest__return

# A cd that fails leaves ptest wherever make started it, and the tar
# then collects that directory as though it were this test's result --
# which is not a failure anybody would find by reading the report.
if ! cd "$tmpdir"
then
    echo "ptest: unable to enter the test's own directory $tmpdir" >&2
    exit 1
fi

# Everything the test left is collected, whatever it is called and
# however much of it there is.  A bare "tar -c *" got three things
# wrong: the glob skips dotfiles, so a ".git" or a ".log" vanished from
# the result; every name was a word on tar's command line, so a file
# called "-f" was read as an option and the archive came out empty;
# and enough files at the top level overran the kernel's argument
# limit, so tar never ran at all.  The last two scored a test that
# passed as an EROR.
#
# So the names go to tar on its standard input, NUL-separated, which
# has no length limit and no option parsing -- GNU tar reads a --null
# list verbatim, and so does bsdtar.  printf is a builtin, so the
# expansion never reaches exec either.  "tar -c ." would have fixed
# all three too, but it names every member "./ptest__return", and
# everything that reads a result -- the report above, the harness,
# the tests that open one another's results -- asks for the bare
# name.  The glob keeps those names; dotglob is what makes it match
# what "." would have, since bash never matches "." or ".." anyway.
shopt -s dotglob
printf '%s\0' * | tar -c --null -T - > "$out"

# By here the result is written, and the test has finished whether or
# not its directory can be removed.  Letting the cleanup's status become
# ptest's would fail the check target of a test that ran, and that is
# worse than noisy: make stops before the report, but the result is
# already on disk, so the next "make check" finds it up to date and is
# green without ever saying the first one wasn't.  A directory that
# still can't be removed is worth a word on stderr, but it is not the
# test's result.
remove_tmpdir
if test -d "$tmpdir"
then
    echo "ptest: unable to remove the test's own directory $tmpdir" >&2
fi
exit 0
