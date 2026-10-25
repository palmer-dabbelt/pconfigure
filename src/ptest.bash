verbose="false"
quiet="false"
check_make_check="true"
abrt_is_fail="false"
check_dirs=()
abrt_dirs=()
check_suite=""
check_results=()
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
        check_dirs+=("$1")
        abrt_dirs+=("$1")
    elif [[ "$1" == "--check-dir" ]]
    then
        # One per project: a build with subprojects has its test
        # results spread across all of them.
        shift
        check_dirs+=("$1")
    elif [[ "$1" == "--check-suite" ]]
    then
        # Reports one named set of tests rather than everything that
        # has been run.  Which tests are in a suite is something the
        # build was told and this was handed: a directory of tarballs
        # says nothing about which of them belong together.
        shift
        check_suite="$1"
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

if [[ "${#check_dirs[@]}" == "0" ]]
then
    # A build with subprojects has its test results spread across all
    # of them, and there's nothing in this directory that says where
    # the others are -- so pconfigure writes the list down next to the
    # Makefile it writes at the same time.  A Makefile old enough not
    # to have one, or a tree that was never configured, still has the
    # one directory everybody has.
    if [[ -r obj/check-dirs ]]
    then
        # A tab and "abrt-is-fail" after a directory is the same thing
        # --abrt-is-fail-dir says on the command line.
        while IFS=$'\t' read -r dir flag
        do
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

if [[ "${#check_dirs[@]}" == "0" ]]
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
    if [[ "$check_suite" == "" ]]
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
            echo "$rest"
        else
            echo "$project/$rest"
        fi
    }

    # Which check directory a result named outright was found under,
    # which is what a whole run gets for free by walking down from the
    # directory itself.  The longest one that matches, so that a
    # project nested inside another is named as itself.
    result_dir() {
        local file="$1"
        local out="."
        local dir

        for dir in "${check_dirs[@]}"
        do
            if [[ "$file" == "$dir"/* ]] && [[ "${#dir}" -gt "${#out}" ]]
            then
                out="$dir"
            fi
        done

        echo "$out"
    }

    # The results this run is reporting on, each with the directory it
    # belongs to.  A whole run is everything in those directories; a
    # suite is exactly the results it was named, since a tarball on
    # disk carries no record of which suites ran the test that left
    # it.
    results() {
        if [[ "$check_suite" != "" ]]
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
            find "$dir" -type f | sort | while read f
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

        while read dir f
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
                why="$(tar -xOf "$f" ptest__output 2>/dev/null \
                       | grep -m 1 '^SKIP:')"
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
                        why="${why#SKIP:}"
                        echo -e "- SKIP\t$name\t${why# }"
                    fi
                    skip=$(expr $skip + 1)
                else
                    if [[ "$quiet" != "true" ]]
                    then
                        echo -e "  PASS\t$name"
                    fi
                    pass=$(expr $pass + 1)
                fi
            elif [[ "$ret" == "1" ]]
            then
                echo -e "* FAIL\t$name"
                fail=$(expr $fail + 1)

                if [[ "$verbose" == "true" ]]
                then
                    cat "$f"
                fi
            elif [[ "$ret" == "134" ]] && dir_abrt_is_fail "$dir"
            then
                echo -e "* FAIL\t$name"
                fail=$(expr $fail + 1)

                if [[ "$verbose" == "true" ]]
                then
                    cat "$f"
                fi
            else
                echo -e "! EROR\t$name"
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

"$test" "$@" >&"$tmpdir"/ptest__output
echo "$?" >"$tmpdir"/ptest__return

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
