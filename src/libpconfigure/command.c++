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

#include "command.h++"
#include "string_utils.h++"
#include <iostream>

command::command(const command_type& type,
                 const std::string& op,
                 const std::string& data,
                 const debug_info::ptr& debug_info,
                 const std::string& qualifier,
                 bool printed_nothing)
    : _type(type),
      _op(op),
      _data(data),
      _debug_info(debug_info),
      _needs_data(false),
      _qualifier(qualifier),
      _written_as(type),
      _printed_nothing(printed_nothing)
{
}

command::command(const command_type& type,
                 const std::string& op,
                 const debug_info::ptr& debug_info,
                 const std::string& qualifier)
    : _type(type),
      _op(op),
      _data(),
      _debug_info(debug_info),
      _needs_data(true),
      _qualifier(qualifier),
      _written_as(type),
      _printed_nothing(false)
{
}

command::ptr command::with_type(const command_type& type)
{
    auto out = this->_needs_data
        ? std::make_shared<command>(
            type,
            this->_op,
            this->_debug_info,
            this->_qualifier)
        : std::make_shared<command>(
            type,
            this->_op,
            this->_data,
            this->_debug_info,
            this->_qualifier,
            this->_printed_nothing);

    out->_written_as = this->_written_as;
    return out;
}

command::ptr command::with_data(const std::string& data)
{
    return std::make_shared<command>(
        this->_type,
        this->_op,
        data,
        this->_debug_info,
        this->_qualifier,
        this->_printed_nothing);
}

command::ptr command::parse_option(const std::string& str,
                                   const debug_info::ptr& d)
{
    if (str == "--verbose")
        return std::make_shared<command>(command_type::VERBOSE, "=", "true", d);
    if (str == "--version")
        return std::make_shared<command>(command_type::VERSION, "=", "true", d);
    if (str == "--help" || str == "-h")
        return std::make_shared<command>(command_type::HELP, "=", "true", d);
    if (str == "--config")
        return std::make_shared<command>(command_type::CONFIG, "+=", d);
    if (str == "--srcpath")
        return std::make_shared<command>(command_type::SRCPATH, "=", d);
    if (str == "--debug")
        return std::make_shared<command>(command_type::DEBUG, "=", "true", d);
    if (str == "--phc")
        return std::make_shared<command>(command_type::PHC, "=", d);
    if (str == "--cross-compile")
        return std::make_shared<command>(command_type::CROSS_COMPILE, "=", d);
    if (str == "--strict")
        return std::make_shared<command>(command_type::STRICT, "=", d);

    return NULL;
}

command::ptr command::parse(const std::string& str,
                            const debug_info::ptr& d,
                            bool printed_nothing)
{
    auto option = parse_option(str, d);
    if (option != NULL)
        return option;

    auto split = string_utils::split_char(str, " ");

    /* What's left of the line once the first few words are taken off
     * it, which is what a corrected line gets built from below.  The
     * line has already been tidied to one space between words, so the
     * words and the spaces after them add up to where the rest
     * starts. */
    auto rest_after = [&](size_t words) {
        size_t offset = 0;
        for (size_t i = 0; i < words && i < split.size(); ++i)
            offset += split[i].size() + 1;
        return offset < str.size() ? std::string(str, offset) : std::string();
    };

    /* Text that starts with an operator is split into the operator and
     * whatever was run up against it, joined to the rest of the line,
     * so that the two refusals below can tell an operator that only
     * wanted a space round it from text that isn't an operator at
     * all.  '+=' is tried first because '=' would match its second
     * half.  Anything that doesn't start with one comes back with no
     * operator and is left alone, and so does an operator with more
     * of an operator after it: "=+" or "+==" is a garbled operator
     * rather than one with a value starting with '+' or '=', and
     * giving the line back spaced out would only be guessing. */
    struct operator_split { std::string op; std::string value; };
    auto split_operator = [](const std::string& text,
                             const std::string& rest) {
        operator_split out;
        for (auto op : {std::string("+="), std::string("=")}) {
            if (text.compare(0, op.size(), op) == 0) {
                if (text.find_first_of("+=", op.size()) == op.size())
                    return out;
                out.op = op;
                out.value = text.substr(op.size());
                break;
            }
        }
        if (out.op.size() > 0 && rest.size() > 0)
            out.value = out.value.size() > 0 ? out.value + " " + rest : rest;
        return out;
    };

    /* A ']' that is there but isn't last closed the name and then
     * kept going, so what's wrong is whatever follows it.  Calling
     * that a name that never closes would send whoever reads it
     * looking for a ']' that's right in front of them.
     *
     * This is looked at before the line is counted, because the
     * likeliest thing to find after the ']' is the operator, run up
     * against it -- and "TESTSRC[net]+= t.bash" is then only two words
     * long, which would otherwise be turned away as a line that
     * couldn't be parsed at all. */
    if (split.size() > 0) {
        auto word = split[0];
        auto open = word.find('[');
        auto close = (open == std::string::npos)
            ? std::string::npos
            : word.find(']', open);
        if (close != std::string::npos && close != word.size() - 1) {
            auto named = word.substr(0, close + 1);
            auto trailing = word.substr(close + 1);
            auto rest = rest_after(1);

            /* A word that starts with the '[' has the name in front
             * of the command rather than after it, and what follows
             * the ']' is the command itself.  Telling that line to end
             * the word at the ']' would leave it with no command on it
             * at all, so it gets told to put the name the other side.
             * The whole line only comes back when the command is all
             * that follows the ']' and the rest of the line is an
             * operator with a value: moving the name is then the only
             * change it needs. */
            if (open == 0) {
                auto command = trailing.substr(0,
                                               trailing.find_first_of("+="));
                auto moved = command + named;
                auto after = split_operator(split.size() > 1 ? split[1]
                                                             : std::string(),
                                            rest_after(2));
                std::cerr << std::to_string(d) << "\n"
                          << "  error: '" << word << "' has its name"
                          << " in brackets before the command\n"
                          << "  the name goes after the command it"
                          << " belongs to, against it with no space"
                          << " before the '['\n";
                if (command == trailing && split.size() > 1
                    && after.op == split[1] && after.value.size() > 0) {
                    std::cerr << "  write '" << moved << " " << after.op
                              << " " << after.value << "'\n";
                } else if (command.size() > 0) {
                    std::cerr << "  write '" << moved << "', then the"
                              << " operator, then the value, with a"
                              << " space between each\n";
                } else {
                    std::cerr << "  write the command, then '" << named
                              << "', then the operator\n";
                }
                abort();
            }

            std::cerr << std::to_string(d) << "\n"
                      << "  error: '" << word << "' has '" << trailing
                      << "' after the ']' that closes its name\n"
                      << "  a command that carries a name ends at the"
                      << " ']', and the operator comes after a space\n";

            /* The commonest thing after the ']' is the operator, run
             * up against the name and sometimes against the value too.
             * Either way it only wants a space each side, and with a
             * value after it the line can be given back whole.
             * Without a value the spaced-out line would be one more
             * line that can't be read, so that one is pointed at
             * instead.
             *
             * Text that has no '=' in it at all may well be the end of
             * a name typed past its ']', and is the only case where
             * moving it into the brackets is a fix worth suggesting:
             * an '=' in the name would be the operator and the value
             * swallowed into it. */
            auto after = split_operator(trailing, rest);
            if (after.op.size() > 0 && after.value.size() > 0) {
                std::cerr << "  the operator needs a space on each side"
                          << " of it\n"
                          << "  write '" << named << " " << after.op
                          << " " << after.value << "'\n";
            } else if (after.op.size() > 0) {
                std::cerr << "  write '" << named << " " << after.op
                          << "' with a space before the '" << after.op
                          << "', and what it's given after it\n";
            } else if (trailing.find('=') == std::string::npos) {
                std::cerr << "  write '" << named << "' with nothing"
                          << " after the ']', moving '" << trailing
                          << "' inside the brackets if it was part of"
                          << " the name\n";
            } else {
                std::cerr << "  write '" << named << "', then a space,"
                          << " then the operator with a space on each"
                          << " side of it, then the value\n";
            }
            abort();
        }
    }

    /* A space before the '[' is an easy slip, and it moves the name
     * into the operator's place: "TESTSRC [net] += t.bash" is a
     * TESTSRC whose operator is "[net]" and whose value is
     * "+= t.bash".  Left to be read that way, the line is warned about
     * as a file with a space in its name and then refused for having
     * an '=' in it, which is advice about a file the line doesn't
     * have.  No operator starts with a '[', so one that does is
     * refused here whatever the command looks like: a command that
     * already carries a name and then has a second one after it is
     * just as far from having an operator. */
    if (split.size() > 1 && split[1].size() > 0 && split[1][0] == '[') {
        auto word = split[1];
        auto close = word.find(']');
        auto has_name = split[0].find('[') != std::string::npos;

        std::cerr << std::to_string(d) << "\n"
                  << "  error: '" << word << "' is where the operator"
                  << " goes, and no operator starts with a '['\n";

        if (has_name) {
            std::cerr << "  '" << split[0] << "' already carries a name,"
                      << " and a command carries at most one: the"
                      << " operator comes straight after it\n";
            abort();
        }

        if (close == std::string::npos || close == 1
            || word.find('[', 1) < close) {
            std::cerr << "  a name in brackets goes against the command,"
                      << " with no space before the '[', and is closed"
                      << " by a ']' before the operator\n";
            abort();
        }

        /* Here the name is whole and was only written apart from its
         * command.  The operator is either run up against the ']' or
         * is the next word along, perhaps with the value run up
         * against it in turn.  When it is one of the two there are and
         * has a value after it, putting the spaces where they go
         * leaves a line shaped the way a command is, so that's what is
         * given back.  Anything else is a second mistake, and a
         * rewrite that fixed the first would only be handing that one
         * back to be found next. */
        auto named = split[0] + word.substr(0, close + 1);
        auto after = word.substr(close + 1);
        auto found = after.size() > 0
            ? split_operator(after, rest_after(2))
            : split_operator(split.size() > 2 ? split[2] : std::string(),
                             rest_after(3));
        auto whole_word = after.size() > 0
            ? std::string()
            : (split.size() > 2 ? split[2] : std::string());

        std::cerr << "  the name is part of the command, so it goes"
                  << " against it with no space before the '['\n";
        if (found.op.size() > 0 && found.value.size() > 0) {
            std::cerr << "  write '" << named << " " << found.op << " "
                      << found.value << "'\n";
        } else if (found.op.size() > 0) {
            std::cerr << "  nothing comes after the '" << found.op
                      << "': write '" << named << " " << found.op
                      << "' and then the value\n";
        } else if (after.size() > 0) {
            std::cerr << "  '" << after << "' after the ']' is not an"
                      << " operator: write '" << named << "', then a"
                      << " space, then the operator\n";
        } else if (whole_word.size() == 0) {
            std::cerr << "  nothing comes after it: write '" << named
                      << "', then the operator, then the value\n";
        } else if (whole_word.find('=') == std::string::npos) {
            std::cerr << "  there is no operator after it either:"
                      << " write '" << named << "', then '+=' or '=',"
                      << " then the value\n";
        } else {
            std::cerr << "  write '" << named << "', and after it an"
                      << " operator that is '+=' or '=' with a value"
                      << " after that\n";
        }
        abort();
    }

    /* A command that sets something to nothing is written with the
     * value left off, since there's no way to write an empty word.
     * That's the only way to take back something a project was given
     * from further up -- a CROSS_COMPILE the whole project inherited,
     * for the one target that has to be built for this machine.
     *
     * CROSS_COMPILE is the only command it means anything for, and
     * the only one allowed to be written that way.  Everything else
     * that takes an '=' names a place rather than a choice, and an
     * empty answer to "where" isn't a project saying "nowhere", it's
     * a line somebody got wrong: an empty LIBDIR would quietly make
     * every library path in the build absolute. */
    auto sets_nothing = (split.size() == 2)
        && (split[1] == "=")
        && (strcasecmp(split[0].c_str(),
                       std::to_string(command_type::CROSS_COMPILE).c_str())
            == 0);

    /* The other way to end up with no value is for backticks to have
     * printed nothing, which the caller knows about and this doesn't.
     * That line is let through as a command with an empty value, so
     * that the name and operator are checked the same way as they are
     * for any other line, and the command processor can say whether
     * this command can be given nothing.  Turning it away here would
     * report a misspelled command as a missing value. */
    auto given_nothing = (split.size() == 2) && printed_nothing;

    /* Too few words to be a command is said nothing about here: every
     * caller already says it couldn't parse the line, naming where the
     * line came from, which is something only the caller knows.  What
     * used to be printed first was how many pieces the split found,
     * which is about this function rather than about what was typed. */
    if (split.size() < 3 && sets_nothing == false && given_nothing == false)
        return NULL;

    auto cmdstr = split[0];
    auto op = split[1];

    /* A command can be written with a name in brackets, which says
     * which of several things of that kind the line lands on.  It
     * belongs to the command rather than to the value: everything
     * after the operator is what the line is about, and the brackets
     * come before it.
     *
     * The name ends the command, so a line that opens the brackets
     * and doesn't close them is a line with no command on it at all.
     * Reading it as far as the '[' and carrying on would take a
     * mistyped name as a command written without one, which is a
     * different command that works. */
    auto qualifier = std::string();
    auto open = cmdstr.find('[');
    if (open != std::string::npos) {
        if (cmdstr[cmdstr.size() - 1] != ']') {
            std::cerr << std::to_string(d) << "\n"
                      << "  error: '" << cmdstr << "' opens a name in"
                      << " brackets and never closes it\n"
                      << "  a command that carries a name ends at the"
                      << " ']', so everything from the '[' onwards is"
                      << " part of the command\n";
            abort();
        }

        qualifier = cmdstr.substr(open + 1, cmdstr.size() - open - 2);
        cmdstr = cmdstr.substr(0, open);

        if (qualifier.size() == 0) {
            std::cerr << std::to_string(d) << "\n"
                      << "  error: '" << cmdstr << "[]' has nothing"
                      << " between its brackets\n"
                      << "  write the name in them, or leave the brackets"
                      << " off: an empty name is not the same thing as"
                      << " no name\n";
            abort();
        }
    }
    auto arg = (sets_nothing || given_nothing)
        ? std::string()
        : std::string(str, split[0].size() + split[1].size() + 2);

    try {
        auto cmd = check_command_type(cmdstr);
        return std::make_shared<command>(cmd, op, arg, d, qualifier,
                                         given_nothing);
    } catch (const char *e) {
        std::cerr << "Unable to parse command: '" << e << "'\n";
        return NULL;
    }  catch (const std::string& e) {
        std::cerr << "Unable to parse command: '" << e << "'\n";
        return NULL;
    } catch(...) {
        std::cerr << "Unknown exception type when parsing command\n";
        return NULL;
    }
}

command::ptr command::consume_extra_arguments(int& i, int argc,
                                              const char **argv)
{
    if (_needs_data == false)
        return shared_from_this();

    /* The argument this wants is the one after the flag, so it's that
     * one that has to be there.  Asking whether the flag itself is in
     * range is asking about something already known, and it let a
     * flag written last on the command line read one past the end. */
    if (i + 1 >= argc)
        return nullptr;

    /* The location is widened to take in the value, since that's what
     * anything complaining about this command will be complaining
     * about: a bad "--strict v9x" quoted as just "--strict" points at
     * the one word on the line that was right. */
    auto value = std::string(argv[++i]);
    auto debug = this->_debug_info->with_line(
        this->_debug_info->line() + " " + value);

    return std::make_shared<command>(
        this->_type,
        this->_op,
        value,
        debug,
        this->_qualifier
    );
}
