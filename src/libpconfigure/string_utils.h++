/*
 * Copyright (C) 2015 Palmer Dabbelt
 *   <palmer@dabbelt.com>
 *
 * This file is part of pconfigure.
 * 
 * pconfigure is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * pconfigure is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with pconfigure.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef STRING_UTILS_HXX
#define STRING_UTILS_HXX

#include <vector>
#include <string>

/* A collection of utilities that deal with simple string
 * operations. */
namespace string_utils {
    /* Cleans up the whitespace of a given string: removes all leading
     * and trailing spaces, and converts any internal whitespace to a
     * single space character. */
    std::string clean_white(const std::string& in);

    /* Splits a string into a number of sub-strings, making a new
     * sub-string every time any one of the delimiter characters is
     * found. */
    std::vector<std::string> split_char(const std::string& in,
                                        const std::string& delims);

    /* Joins the string using delim as the separator between
     * elements. */
    std::string join(const std::vector<std::string>& in,
                     const std::string& delim = "");

    /* Computes a simple hash code for a vector of strings. */
    std::string hash(const std::vector<std::string>& in);

    /* TRUE when a filename ends with the given extension.  A name
     * that is nothing but the extension has no stem, so it isn't
     * one. */
    bool has_extension(const std::string& name, const std::string& extension);

    /* One word of shell, quoted so that whatever shell runs it takes
     * the whole of it as one word however many spaces, semicolons or
     * asterisks are in the middle.
     *
     * Every recipe pconfigure writes is half text somebody put in a
     * Configfile, and the interesting halves all want this: a
     * "MAKEOPS += KCFLAGS=-O2 -g" is a variable whose value has a
     * space in it, a "--configure-arg CXXFLAGS=-g -O2" is an argument
     * whose value has a space in it, and a cmake
     * "-DLLVM_ENABLE_PROJECTS=clang;lld" has something worse.  Handed
     * to a shell unquoted, the first of those becomes a variable and a
     * flag, the second becomes an argument and another argument, and
     * the third runs cmake and then tries to run a program called
     * "lld" -- and all three of them are accepted without a murmur at
     * configure time and fail somewhere in the middle of a build.
     *
     * What this deliberately does not do is take the value apart.
     * make expands a recipe before any shell sees it, so "$(abspath
     * x)" still means what it says even from inside these quotes --
     * make has no idea they are there -- and still gets to come back
     * with a path that has a space in it.  A quoting that understood
     * what it was quoting would have to decide what to do with that,
     * and every answer to that question is wrong for somebody.
     *
     * Single quotes rather than double, because a single-quoted shell
     * string has exactly one character it cannot hold and no
     * expansions at all: no '$', no backtick, no backslash, nothing
     * to reason about.  The one character it cannot hold is handled
     * the only way it can be -- stop quoting, escape the quote out in
     * the open, start quoting again -- which is why the result is
     * sometimes longer than it looks like it should be.
     *
     * This lives here because it used to be written out by hand in
     * four separate places, and a fix to the escaping made in one of
     * four copies is a fix the other three go on not having.
     *
     * Which places, and which callers there are now, is deliberately
     * not written down here.  A comment that names its callers is a
     * comment that is one commit away from being wrong, and the last
     * one went wrong in two ways at once: it missed a caller added by
     * the same change that wrote it, and it said that three build
     * systems quoted their configure arguments when one of them
     * deliberately does not.  What the callers have in common is the
     * whole of what there is to say about them -- each is putting a
     * word somebody wrote in a Configfile onto a command line a shell
     * is going to read -- and a grep answers the rest without having
     * to be kept true.
     *
     * Being one function is also not the same as being one tested
     * function, which is the other thing hoisting it was expected to
     * buy and did not.  A caller that quotes and a caller that forgot
     * look identical from in here, so each of them is pinned by a
     * test where it is written rather than by a test of this.
     *
     * The one thing that wants quoting and doesn't want this on its
     * own is text being written down rather than run -- an "echo" in
     * a recipe, or an option recorded in a signature file.  Those
     * want make's expansion kept out too, which is unexpanded() and
     * echoed() below. */
    std::string quoted(const std::string& in);

    /* A string make will hand on exactly as it was written.
     *
     * make expands a recipe before the shell ever sees it, which is
     * what lets a MAKEOPS say "$(abspath x)" and mean it -- and which
     * is exactly wrong for text that is being written down rather
     * than run.  What goes into a signature file has to be the option
     * somebody wrote, character for character: a '$' that got
     * expanded on the way in would record whatever a variable
     * happened to hold rather than what the Configfile said, and two
     * runs that said the same thing would disagree.  A '$' in a
     * sentence a recipe prints wants the same thing for a harder
     * reason -- see echoed().
     *
     * This is only half a quoting and is no use on its own.  It is
     * separate from echoed() because the one caller that wants the
     * doubling without the quoting -- an option being recorded, which
     * has a further rewrite of its own to get out from under -- would
     * otherwise have to undo what echoed() did. */
    std::string unexpanded(const std::string& in);

    /* One sentence, spelled so that an "echo" in a recipe prints
     * exactly the characters that went in.
     *
     * Single quotes rather than the double quotes this was first
     * written with, because half of what such a recipe has to say is
     * something somebody wrote in a Configfile, and a Configfile is
     * allowed quotes of its own.  Inside a double-quoted echo those
     * become the message's quoting rather than part of what it says.
     * A balanced pair of them merely disappears -- 'sh -c "touch
     * configure"' comes out spelled without its quotes, which is a
     * message about a Configfile line that no longer matches the
     * Configfile line.  An odd one is worse: it ends the message's
     * own quoting and hands the rest of the recipe to the shell as
     * whatever it makes of it, so a diagnostic whose entire job is to
     * explain a mistake becomes a syntax error at build time.  Which
     * is all quoted() does, so that is what does it.
     *
     * The doubling in front of it is the whole of the difference from
     * quoted(), and it is the difference.  quoted() is for a value on
     * a command line, where "$(abspath x)" means what it says and is
     * meant to; this is a sentence about what a Configfile said, and
     * what the Configfile said is the useful thing to print.  It also
     * shuts the last door onto a syntax error, since what an
     * expansion comes back with is text this had no chance to quote.
     *
     * The doubling happens first and the quoting second, which reads
     * like an order that might matter and isn't: quoted() has nothing
     * to say about a '$' and doubling has nothing to say about a
     * quote, so neither pass can see what the other one wrote.
     *
     * What this does not stop, and must not, is the path rewriting
     * every recipe line goes through on its way into the Makefile: a
     * quote is one of the characters that starts a word, so a path
     * just inside these quotes is still found and still gets the
     * variable naming its project put in front of it.  That is what
     * keeps a diagnostic about a file naming that file from wherever
     * make was run.  A caller that wants the rewriting kept out as
     * well wants more than this. */
    std::string echoed(const std::string& in);
}

#endif
